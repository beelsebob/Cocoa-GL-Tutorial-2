//
//  GLTutorialController.m
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import "GLTutorialController.h"

#import "error.h"

typedef struct
{
    Vector4 position;
    Colour colour;
} Vertex;

@interface GLTutorialController ()

- (void)createOpenGLView;

- (void)createDisplayLink;

- (void)createOpenGLResources;
- (void)loadShader;
- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file;
- (void)linkProgram:(GLuint)program;
- (void)validateProgram:(GLuint)program;

- (void)loadBufferData;

- (void)loadTextureData;
- (GLuint)loadTextureNamed:(NSString *)name;

- (void)renderForTime:(CVTimeStamp)time;

@end

CVReturn displayCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

CVReturn displayCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
{
    GLTutorialController *controller = (GLTutorialController *)displayLinkContext;
    [controller renderForTime:*inOutputTime];
    return kCVReturnSuccess;
}

@implementation GLTutorialController
{
    CVDisplayLinkRef displayLink;
    
    GLuint shaderProgram;
    GLuint vertexArrayObject;
    GLuint vertexBuffer;
    
    GLint uniforms[kNumUniforms];
    
    GLint colourAttribute;
    GLint positionAttribute;
}

@synthesize view;
@synthesize window;

- (void)awakeFromNib
{
    [self createOpenGLView];
    [self createOpenGLResources];
    [self createDisplayLink];
}

- (void)createOpenGLView
{
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] =
    {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize    , 24                           ,
        NSOpenGLPFAAlphaSize    , 8                            ,
        NSOpenGLPFADoubleBuffer ,
        NSOpenGLPFAAccelerated  ,
        NSOpenGLPFANoRecovery   ,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes] autorelease];
    [self setView:[[[NSOpenGLView alloc] initWithFrame:[[[self window] contentView] bounds] pixelFormat:pixelFormat] autorelease]];
    [[[self window] contentView] addSubview:[self view]];
}

- (void)createDisplayLink
{
    CGDirectDisplayID displayID = CGMainDisplayID();
    CVReturn error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    
    if (kCVReturnSuccess == error)
    {
        CVDisplayLinkSetOutputCallback(displayLink, displayCallback, self);
        CVDisplayLinkStart(displayLink);
    }
    else
    {
        NSLog(@"Display Link created with error: %d", error);
        displayLink = NULL;
    }
}

- (void)createOpenGLResources
{
    [[[self view] openGLContext] makeCurrentContext];
    
    [self loadShader];
    [self loadBufferData];
    [self loadTextureData];
}

- (void)loadShader
{
    GLuint vertexShader;
    GLuint fragmentShader;
    
    vertexShader   = [self compileShaderOfType:GL_VERTEX_SHADER   file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]];
    fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
    
    if (0 != vertexShader && 0 != fragmentShader)
    {
        shaderProgram = glCreateProgram();
        GetError();
        
        glAttachShader(shaderProgram, vertexShader  );
        GetError();
        glAttachShader(shaderProgram, fragmentShader);
        GetError();
        
        glBindFragDataLocation(shaderProgram, 0, "fragColour");
        
        [self linkProgram:shaderProgram];
        
        uniforms[kPositionUniform]   = glGetUniformLocation(shaderProgram, "p"         );
        GetError();
        uniforms[kBackgroundUniform] = glGetUniformLocation(shaderProgram, "background");
        GetError();
        uniforms[kHoleUniform]       = glGetUniformLocation(shaderProgram, "hole"      );
        GetError();
        for (int uniformNumber = 0; uniformNumber < kNumUniforms; uniformNumber++)
        {
            if (uniforms[uniformNumber] < 0)
            {
                [NSException raise:kFailedToInitialiseGLException format:@"Shader is missing a uniform."];
            }
        }
        colourAttribute   = glGetAttribLocation(shaderProgram, "colour"  );
        GetError();
        if (colourAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'colour' attribute."];
        }
        positionAttribute = glGetAttribLocation(shaderProgram, "position");
        GetError();
        if (positionAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];
        }
        
        glDeleteShader(vertexShader  );
        GetError();
        glDeleteShader(fragmentShader);
        GetError();
    }
    else
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed."];
    }
}

- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file
{
    GLuint shader;
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to read shader file %@", file];
    }
    
    shader = glCreateShader(type);
    GetError();
    glShaderSource(shader, 1, &source, NULL);
    GetError();
    glCompileShader(shader);
    GetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader compilation failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    GetError();
    if (0 == status)
    {
        glDeleteShader(shader);
        GetError();
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed for file %@", file];
    }
    
    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);
    GetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader program linking failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    GetError();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)validateProgram:(GLuint)program
{
    GLint logLength;
    
    glValidateProgram(program);
    GetError();
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();
        NSLog(@"Program validation produced errors:\n%s", log);
        free(log);
    }
    
    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    GetError();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)loadBufferData
{
    Vertex vertexData[4] = {
        { .position = { .x=-0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=0.0, .b=0.0, .a=1.0 } },
        { .position = { .x=-0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=1.0, .b=0.0, .a=1.0 } },
        { .position = { .x= 0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=0.0, .b=1.0, .a=1.0 } },
        { .position = { .x= 0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=1.0, .b=1.0, .a=1.0 } }
    };
    
    glGenVertexArrays(1, &vertexArrayObject);
    GetError();
    glBindVertexArray(vertexArrayObject);
    GetError();
    
    glGenBuffers(1, &vertexBuffer);
    GetError();
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GetError();
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
    GetError();
    
    glEnableVertexAttribArray((GLuint)positionAttribute);
    GetError();
    glEnableVertexAttribArray((GLuint)colourAttribute  );
    GetError();
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
    GetError();
    glVertexAttribPointer((GLuint)colourAttribute  , 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, colour  ));
    GetError();
}

- (void)loadTextureData
{
    GLuint backgroundTexture = [self loadTextureNamed:@"background"];
    GLuint holeTexture       = [self loadTextureNamed:@"hole"      ];
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, backgroundTexture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, holeTexture      );
}

- (GLuint)loadTextureNamed:(NSString *)name
{
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[[NSBundle mainBundle] URLForImageResource:name], NULL);
    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);
    size_t width  = CGImageGetWidth (image);
    size_t height = CGImageGetHeight(image);
    CGRect rect = CGRectMake(0.0f, 0.0f, width, height);
    
    void *imageData = malloc(width * height * 4);
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colourSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    CFRelease(colourSpace);
    CGContextTranslateCTM(ctx, 0, height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, rect, image);
    CGContextRelease(ctx);
    CFRelease(image);
    
    GLuint glName;
    glGenTextures(1, &glName);
    GetError();
    glBindTexture(GL_TEXTURE_2D, glName);
    GetError();
    
    glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint)width);
    GetError();
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    GetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    GetError();

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)width, (int)height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, imageData);
    GetError();
    
    return glName;
}

- (void)renderForTime:(CVTimeStamp)time
{
    [[[self view] openGLContext] makeCurrentContext];
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    GetError();
    glClear(GL_COLOR_BUFFER_BIT);
    GetError();
    
    glUseProgram(shaderProgram);
    GetError();
    
    GLfloat timeValue = (GLfloat)(time.videoTime) / (GLfloat)(time.videoTimeScale);
    Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };
    glUniform2fv(uniforms[kPositionUniform], 1, (const GLfloat *)&p);
    GetError();
    glUniform1i(uniforms[kBackgroundUniform], 0);
    GetError();
    glUniform1i(uniforms[kHoleUniform]      , 1);
    GetError();
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GetError();
    
    [[[self view] openGLContext] flushBuffer];
}

- (void)dealloc
{
    glDeleteProgram(shaderProgram);
    GetError();
    glDeleteBuffers(1, &vertexBuffer);
    GetError();
    
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
    [view release];
    
    [super dealloc];
}

@end
