//
//  GLTutorialController.h
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVDisplayLink.h>
#import <OpenGL/gl3.h>

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

enum Uniforms
{
    kPositionUniform = 0,
    kBackgroundUniform  ,
    kHoleUniform        ,
    kNumUniforms
};

typedef struct
{
    GLfloat x,y;
} Vector2;

typedef struct
{
    GLfloat x,y,z,w;
} Vector4;

typedef struct
{
    GLfloat r,g,b,a;
} Colour;

@interface GLTutorialController : NSObject

@property (nonatomic, readwrite, retain) IBOutlet NSOpenGLView *view;
@property (nonatomic, readwrite, retain) IBOutlet NSWindow *window;

@end
