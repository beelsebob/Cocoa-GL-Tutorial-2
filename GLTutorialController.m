//
//  GLTutorialController.m
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import "GLTutorialController.h"

typedef struct
{
    Vector4 position;
    Colour colour;
} Vertex;

@interface GLTutorialController ()

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

@synthesize view;

- (void)awakeFromNib
{
    isFirstRender = YES;
    
    [self createOpenGLResources];
    [self createDisplayLink];
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
        eglGetError();
        
        glAttachShader(shaderProgram, vertexShader  );
        eglGetError();
        glAttachShader(shaderProgram, fragmentShader);
        eglGetError();
        
        [self linkProgram:shaderProgram];
        
        positionUniform          = glGetUniformLocation(shaderProgram, "p"         );
        eglGetError();
        backgroundTextureUniform = glGetUniformLocation(shaderProgram, "background");
        eglGetError();
        holeTextureUniform       = glGetUniformLocation(shaderProgram, "hole"      );
        eglGetError();
        colourAttribute          = glGetAttribLocation (shaderProgram, "colour"    );
        eglGetError();
        positionAttribute        = glGetAttribLocation (shaderProgram, "position"  );
        eglGetError();
        
        glDeleteShader(vertexShader  );
        eglGetError();
        glDeleteShader(fragmentShader);
        eglGetError();
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
    eglGetError();
    glShaderSource(shader, 1, &source, NULL);
    eglGetError();
    glCompileShader(shader);
    eglGetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    eglGetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        eglGetError();
        NSLog(@"Shader compilation failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    eglGetError();
    if (0 == status)
    {
        glDeleteShader(shader);
        eglGetError();
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed for file %@", file];
    }
    
    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);
    eglGetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    eglGetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        eglGetError();
        NSLog(@"Shader program linking failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    eglGetError();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)validateProgram:(GLuint)program
{
    GLint logLength;
    
    glValidateProgram(program);
    eglGetError();
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    eglGetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        eglGetError();
        NSLog(@"Program validation produced errors:\n%s", log);
        free(log);
    }
    
    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    eglGetError();
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
    
    glGenBuffers(1, &vertexBuffer);
    eglGetError();
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    eglGetError();
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
    eglGetError();
    
    glEnableVertexAttribArray((GLuint)positionAttribute);
    eglGetError();
    glEnableVertexAttribArray((GLuint)colourAttribute  );
    eglGetError();
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
    eglGetError();
    glVertexAttribPointer((GLuint)colourAttribute  , 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, colour  ));
    eglGetError();
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
    NSImage *image = [NSImage imageNamed:name];
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]] autorelease];
    NSImage *premultiplied = [[[NSImage alloc] initWithSize:[image size]] autorelease];
    if (NSAlphaNonpremultipliedBitmapFormat & [bitmap bitmapFormat])
    {
        [premultiplied lockFocus];
        [bitmap drawAtPoint:NSMakePoint(0.0, 0.0)];
        [premultiplied unlockFocus];
    }
    else
    {
        [premultiplied addRepresentation:bitmap];
    }
    
    CGImageRef cgTex = [premultiplied CGImageForProposedRect:NULL context:NULL hints:nil];
    unsigned long width  = CGImageGetWidth (cgTex);
    unsigned long height = CGImageGetHeight(cgTex);
    unsigned long numPixels = width * height;
    unsigned char *imgData = malloc(numPixels * 4);
    
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(imgData, width, height, 8, width * 4, colourSpace, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    CGContextClearRect(ctx, CGRectMake(0, 0, width, height));
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgTex);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colourSpace);
    
    GLuint glName;
    glGenTextures(1, &glName);
    eglGetError();
    glBindTexture(GL_TEXTURE_2D, glName);
    eglGetError();
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    eglGetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    eglGetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    eglGetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    eglGetError();
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    eglGetError();

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA , GL_UNSIGNED_BYTE, imgData);
    eglGetError();
    
    return glName;
}

- (void)renderForTime:(CVTimeStamp)time
{
    if (!isFirstRender)
    {
        [[[self view] openGLContext] flushBuffer];
    }
    else
    {
        isFirstRender = NO;
    }
    
    [[[self view] openGLContext] makeCurrentContext];
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    eglGetError();
    glClear(GL_COLOR_BUFFER_BIT);
    eglGetError();
    
    glUseProgram(shaderProgram);
    eglGetError();
    
    GLfloat timeValue = (GLfloat)(time.videoTime) / (GLfloat)(time.videoTimeScale);
    Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };
    glUniform2fv(positionUniform, 1, (const GLfloat *)&p);
    eglGetError();
    glUniform1i(backgroundTextureUniform, 0);
    eglGetError();
    glUniform1i(holeTextureUniform      , 1);
    eglGetError();
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    eglGetError();
}

- (void)dealloc
{
    glDeleteProgram(shaderProgram);
    eglGetError();
    glDeleteBuffers(1, &vertexBuffer);
    eglGetError();
    
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
    [view release];
    
    [super dealloc];
}

@end
