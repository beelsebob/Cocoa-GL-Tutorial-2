# Cocoa GL Tutorial Part 2

This tutorial builds on my first OpenGL tutorial and explains how to get started with texturing.  Again, it contains code specific to Cocoa for loading textures, and code that is general to all OpenGL use.  You can use either part of the tutorial independently.

## Texture Loading In Cocoa

To give OpenGL texture data we must get ourselves the bitmap data in a format that OpenGL is ready to understand.  In this case we're going to use 8 bit per channel, premultiplied, RGBA data.  To get that out of a png file we use CGImageSource to load the texture.  We allocate some memory for a graphics context to draw into, and then create a graphics context with a known component ordering, and with premultiplying set on:

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

We transform the context so as not to get flipped data out:

    CGContextTranslateCTM(ctx, 0, height);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);

Finally, we draw into this context to fill our data buffer:

    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, rect, image);
    CGContextRelease(ctx);
    CFRelease(image);

We're now ready to get on with passing the data to OpenGL.

## Setting up a texture

To give OpenGL texture data, we first need to create somewhere to store it on the graphics card.  We do so by generating textures:

    GLuint glName;
    glGenTextures(1, &glName);
    GetError();
    glBindTexture(GL_TEXTURE_2D, glName);
    GetError();

We need to specify some filtering options - we tell OpenGL that we want biliniar filtering when the texture is sampled, and that we want to clamp the edge values if we try and sample off the edge of the texture:

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

Finally, we give OpenGL our image data, note that we specify BGRA ordering, and that the components are going to be reversed in the data.  This matches the ARGB order that we used when creating our CGContext.  Note that we now free the image data, as OpenGL takes a copy of it:

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (int)width, (int)height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, imgData);
    GetError();
    free(imageData);

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
    fragColour = colourV + (1.0 - holeColour.a) * texture(background, positionV);

Don't forget to look at my [third tutorial](http://www.github.org/beelsebob/Cocoa-GL-Tutorial-3), which covers 3D projection.
