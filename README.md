# Cocoa GL Tutorial Part 2

This tutorial builds on my first OpenGL tutorial and explains how to get started with texturing.  Again, it contains code specific to Cocoa for loading textures, and code that is general to all OpenGL use.  You can use either part of the tutorial independently.

## Texture Loading In Cocoa

To give OpenGL texture data we must get ourselves the bitmap data in a format that OpenGL is ready to understand.  In this case we're going to use 8 bit per channel, premultiplied, RGBA data.  To get that out of a png file we use NSImage to load the texture:

    NSImage *image = [NSImage imageNamed:name];

The first thing we do is make sure that the image has premultiplied alpha by drawing it into a new image:

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

Now that we have our premultiplied image, we want to set about getting the image data out of it.  To do this, we create a Core Graphics context of the relevant size, using a chunk of memory we're going to use to pass the data to OpenGL.

    CGImageRef cgTex = [premultiplied CGImageForProposedRect:NULL context:NULL hints:nil];
    unsigned long width  = CGImageGetWidth (cgTex);
    unsigned long height = CGImageGetHeight(cgTex);
    unsigned long numPixels = width * height;
    unsigned char *imgData = malloc(numPixels * 4);
    
    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(imgData, width, height, 8, width * 4, colourSpace, kCGImageAlphaPremultipliedLast);

We transform the context so as not to get a flipped image out.

    CGContextTranslateCTM(ctx, 0, height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);

And we draw into the context.

    CGContextClearRect(ctx, CGRectMake(0, 0, width, height));
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgTex);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colourSpace);

We're now ready to get on with passing the data to OpenGL.

## Setting up a texture

To give OpenGL texture data, we first need to create somewhere to store it on the graphics card.  We do so by generating textures:

    GLuint glName;
    glGenTextures(1, &glName);
    GetError();
    glBindTexture(GL_TEXTURE_2D, glName);
    GetError();

We need to specify some filtering options - we tell OpenGL that we want biliniar filtering when the texture is sampled, and that we want to clamp the edge values if we try and sample off the edge of the texture:

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

Finally, we give OpenGL our image data:

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA , GL_UNSIGNED_BYTE, imgData);
    GetError();

Once our two textures are uploaded to the graphics card, we want to set up texture units ready to access the textures.  Note that we do this so that we can access both textures at the same time in our shader.  glActiveTexture tells OpenGL that we want to use a different texture unit, while glBindTexture sets the texture as the current for that unit:

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, backgroundTexture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, holeTexture      );

And inform our shader of which texture units our two textures are residing in:

    glUniform1i(uniforms[kBackgroundUniform], 0);
    GetError();
    glUniform1i(uniforms[kHoleUniform]      , 1);
    GetError();

Finally, to see the completed result, our fragment shader is now responsible for sampling the two textures to compute the final colour for the pixel:

    vec4 holeColour = texture(hole, texCoordV);
    gl_FragColor = colourV + (1.0 - holeColour.a) * texture(background, positionV);
