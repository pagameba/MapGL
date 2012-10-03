//
//  MSOpenGLView.h
//  awesomeness
//
//  Created by Paul Spencer on 2012-09-21.
//  Copyright (c) 2012 DM Solutions Group Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#include <vector>

#import "Math/Vector.hpp"
#import "Math/Matrix.hpp"
#import "Math/Quaternion.hpp"

typedef struct {
    vec3 Position;
    vec4 Color;
} Vertex;

using namespace std;

@interface MGLView : UIView <UIGestureRecognizerDelegate> {
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    GLuint _frameBuffer;
    GLuint _colorRenderBuffer;
    
    GLuint _positionSlot;
    GLuint _colorSlot;
    
    GLint _backingWidth;
    GLint _backingHeight;
    
    GLuint _projectionUniform;
    GLuint _modelViewUniform;
        
    UIGestureRecognizer *panGesture;
    UIGestureRecognizer *pinchGesture;
    UIGestureRecognizer *rotateGesture;
    
    mat4 modelViewMatrix;
    mat4 currentTransformation;
    vec2 currentTranslation;
    float currentScale;
    float currentRotation;
    BOOL needsRender;
}

@end
