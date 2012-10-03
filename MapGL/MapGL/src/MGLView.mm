//
//  MSOpenGLView.m
//  awesomeness
//
//  Created by Paul Spencer on 2012-09-21.
//  Copyright (c) 2012 DM Solutions Group Inc. All rights reserved.
//

#import "MGLView.h"

const GLubyte Indices[] = {
    // Front
    0, 1, 2,
    2, 3, 0,
    // Back
    4, 6, 5,
    4, 7, 6,
    // Left
    2, 7, 3,
    7, 6, 2,
    // Right
    0, 4, 1,
    4, 1, 5,
    // Top
    6, 2, 1,
    1, 6, 5,
    // Bottom
    0, 3, 7,
    0, 7, 4
};

@implementation MGLView

- (id) init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void) setup
{
    // Initialization code
    [self setupLayer];
    [self setupContext];
    [self setupBuffers];
    [self compileShaders];
    [self setupVBOs];
    [self setupDisplayLink];
    
    modelViewMatrix =  mat4::Identity().Scale(.1);
    currentTransformation =  mat4::Identity();
    currentTranslation = vec2(0,0);
    currentScale =  1.0;
    currentRotation =  0.0;
}

- (void) dealloc
{
    if (_colorRenderBuffer)
    {
        glDeleteFramebuffers(1, &_colorRenderBuffer);
        _colorRenderBuffer = 0;
    }
    
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
        
    // Tear down context
    if ([EAGLContext currentContext] == _context)
    {
        [EAGLContext setCurrentContext:nil];
    }
    _context = nil;
}

- (void)layoutSubviews
{
	NSLog(@"Scale factor: %f", self.contentScaleFactor);
    [self resizeFromLayer];
    [self render:nil];
}

- (BOOL)resizeFromLayer
{
    // need to redo the buffers for new dimensions
    [self setupBuffers];
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }

    // resize the viewport
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    // Set the projection matrix according to the aspect ratio
    // of the viewport
    GLfloat proj[16];
    float aspect = MAX((float)_backingHeight/(float)_backingWidth, (float)_backingWidth/(float)_backingHeight);
    if (_backingWidth > _backingHeight) {
        [self loadOrthoMatrix:proj left:-0.5*aspect right:0.5*aspect bottom:-0.5 top:0.5 near:1 far:10];
    } else {
        [self loadOrthoMatrix:proj left:-0.5 right:0.5 bottom:-0.5 *aspect top:0.5*aspect near:1 far:10];
        
    }
    glUniformMatrix4fv(_projectionUniform, 1, 0, proj);

    return YES;
}


+ (Class) layerClass {
    return [CAEAGLLayer class];
}

#pragma mark Gesture Recognizer Delegate

- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark Gesture Recognizer callbacks

- (void) pan: (UIPanGestureRecognizer*) gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        return [self commitCurrentTransformation];
    }

    // offset from the beginning of the gesture
    CGPoint point = [gestureRecognizer translationInView: self];
    
    float w = CGRectGetWidth(self.frame);
    float h = CGRectGetHeight(self.frame);
    float aspect = MAX(w/h,h/w);
    
    // delta since this method was last called
    float dx = point.x - currentTranslation.x;
    float dy = point.y - currentTranslation.y;
    currentTranslation.x = point.x;
    currentTranslation.y = point.y;
    
    // update the current transformation by the computed deltas
    // noting that y is inverted
    // scaling the dy value by the aspect ratio seems to be required
    // to get the proper behaviour but I don't know why.
    currentTransformation = currentTransformation * currentTransformation.Translate(dx/w,-1*aspect*dy/h, 0);
    needsRender = YES;
}

- (void) pinch: (UIPinchGestureRecognizer* ) gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        return [self commitCurrentTransformation];
    }

    // scale is from beginning of gesture so revert current scale and
    // apply the new one
    currentTransformation = currentTransformation * currentTransformation.Scale(1/currentScale) * currentTransformation.Scale(gestureRecognizer.scale);
    
    currentScale = gestureRecognizer.scale;

    needsRender = YES;
}

- (void) rotate: (UIRotationGestureRecognizer*) gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        return [self commitCurrentTransformation];
    }

    // rotation is from the beginning of the gesture so compute the
    // difference and convert to degrees.  We are rotating the model
    // so reverse it.
    currentTransformation = currentTransformation * currentTransformation.Rotate((gestureRecognizer.rotation - currentRotation)*-180/M_PI);
    
    currentRotation = gestureRecognizer.rotation;
    needsRender = YES;
}

// apply the currentTransformation to the modelViewMatrix and
// reset our current values for the next set of gestures
- (void) commitCurrentTransformation
{
    modelViewMatrix = modelViewMatrix * currentTransformation;
    currentTransformation = mat4::Identity();
    currentScale = 1.0;
    currentRotation = 0;
    currentTranslation = vec2(0,0);
    needsRender = YES;
}

// create the EAGL layer and register our gesture handlers
- (void) setupLayer
{
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
    
    // Set scaling to account for Retina display
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
    {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }

    panGesture = [[UIPanGestureRecognizer alloc] initWithTarget: self action:@selector(pan:)];
    pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget: self action:@selector(pinch:)];
    rotateGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotate:)];

    [self addGestureRecognizer: panGesture];
    [self addGestureRecognizer: pinchGesture];
    [self addGestureRecognizer: rotateGesture];
    
    panGesture.delegate = self;
    pinchGesture.delegate = self;
    rotateGesture.delegate = self;

}

// create the EAGL context
- (void) setupContext
{
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void) setupBuffers
{
    if (!_colorRenderBuffer) {
        glGenRenderbuffers(1, &_colorRenderBuffer);
    }
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];

    if (!_frameBuffer) {
        glGenFramebuffers(1, &_frameBuffer);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
}

- (GLuint) compileShader: (NSString*) shaderName withType: (GLenum)shaderType
{
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"glsl"];
    NSError* error;
    
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    GLuint shaderHandle = glCreateShader(shaderType);
    
    const char* shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String: messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    return shaderHandle;
}

- (void) compileShaders
{
    GLuint vertexShader = [self compileShader: @"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader: @"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(programHandle);

    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);

    _projectionUniform = glGetUniformLocation(programHandle, "Projection");
    _modelViewUniform = glGetUniformLocation(programHandle, "Modelview");

}

- (void) setupVBOs
{
    Vertex Vertices[8];
    
    Vertices[0].Position = vec3(1,-1,0);
    Vertices[0].Color = vec4(1,0,0,1);
    Vertices[1].Position = vec3(1,1,0);
    Vertices[1].Color = vec4(1,0,0,1);
    Vertices[2].Position = vec3(-1,1,0);
    Vertices[2].Color = vec4(0,1,0,1);
    Vertices[3].Position = vec3(-1,-1,0);
    Vertices[3].Color = vec4(0,1,0,1);
    Vertices[4].Position = vec3(1,-1,-1);
    Vertices[4].Color = vec4(1,0,0,1);
    Vertices[5].Position = vec3(1,1,-1);
    Vertices[5].Color = vec4(1,0,0,1);
    Vertices[6].Position = vec3(-1,1,-1);
    Vertices[6].Color = vec4(0,1,0,1);
    Vertices[7].Position = vec3(-1,-1,-1);
    Vertices[7].Color = vec4(0,1,0,1);

    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), &Vertices, GL_STATIC_DRAW);
    
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), &Indices, GL_STATIC_DRAW);
    
}

- (void) setupDisplayLink
{
    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector: @selector(render:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far;
{
    GLfloat r_l = right - left;
    GLfloat t_b = top - bottom;
    GLfloat f_n = far - near;
    GLfloat tx = - (right + left) / (right - left);
    GLfloat ty = - (top + bottom) / (top - bottom);
    GLfloat tz = - (far + near) / (far - near);
    
    matrix[0] = 2.0f / r_l;
    matrix[1] = 0.0f;
    matrix[2] = 0.0f;
    matrix[3] = tx;
    
    matrix[4] = 0.0f;
    matrix[5] = 2.0f / t_b;
    matrix[6] = 0.0f;
    matrix[7] = ty;
    
    matrix[8] = 0.0f;
    matrix[9] = 0.0f;
    matrix[10] = 2.0f / f_n;
    matrix[11] = tz;
    
    matrix[12] = 0.0f;
    matrix[13] = 0.0f;
    matrix[14] = 0.0f;
    matrix[15] = 1.0f;
}


- (void) render: (CADisplayLink*) displayLink
{
    if (needsRender) {
        glClearColor(0.0, 104.0/255.0, 55.0/255.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        
        glUniformMatrix4fv(_modelViewUniform, 1, 0, (modelViewMatrix * currentTransformation).Pointer());
        
        glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
        glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)(sizeof(float)*3));
        
        glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
        
        [_context presentRenderbuffer: GL_RENDERBUFFER];
        needsRender = NO;
    }
}

@end
