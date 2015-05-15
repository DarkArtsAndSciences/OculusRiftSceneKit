#import "OculusRiftSceneKitView.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#define EYE_RENDER_RESOLUTION_X 800
#define EYE_RENDER_RESOLUTION_Y 1000

#define LEFT 0
#define RIGHT 1

NSString *const kOCVRVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const kOCVRPassthroughFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );

// Lens correction shader drawn from the Oculus VR SDK
NSString *const kOCVRLensCorrectionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 uniform vec2 LensCenter;
 uniform vec2 ScreenCenter;
 uniform vec2 Scale;
 uniform vec2 ScaleIn;
 uniform vec4 HmdWarpParam;
 
 vec2 HmdWarp(vec2 in01)
 {
     vec2 theta = (in01 - LensCenter) * ScaleIn; // Scales to [-1, 1]
     float rSq = theta.x * theta.x + theta.y * theta.y;
     vec2  theta1 = theta * (HmdWarpParam.x + HmdWarpParam.y * rSq + HmdWarpParam.z * rSq * rSq + HmdWarpParam.w * rSq * rSq * rSq);
     return ScreenCenter + Scale * theta1;
 }
 void main()
 {
     vec2 tc = HmdWarp(textureCoordinate);
     if (!all(equal(clamp(tc, ScreenCenter-vec2(0.5,0.5), ScreenCenter+vec2(0.5,0.5)), tc)))
         gl_FragColor = vec4(0);
     else
         gl_FragColor = texture2D(inputImageTexture, tc);
 }
 );

@interface OculusRiftSceneKitView()
{
	//OculusRiftDevice *oculusRiftDevice;
	CGFloat interpupillaryDistance;
	
    SCNRenderer *leftEyeRenderer, *rightEyeRenderer;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    GLint lensCenterUniform, screenCenterUniform, scaleUniform, scaleInUniform, hmdWarpParamUniform;
    
    GLuint leftEyeTexture, rightEyeTexture;
    GLuint leftEyeDepthTexture, rightEyeDepthTexture;
    GLuint leftEyeFramebuffer, rightEyeFramebuffer;
    GLuint leftEyeDepthBuffer, rightEyeDepthBuffer;
    
    CVDisplayLinkRef displayLink;
    
    BOOL leftSceneReady, rightSceneReady;
    
    SCNNode *leftEyeCameraNode, *rightEyeCameraNode;
    
    CGFloat redBackgroundComponent, blueBackgroundComponent, greenBackgroundComponent, alphaBackgroundComponent;
}

- (void)setupPixelFormat;
- (void)commonInit;
- (void)renderStereoscopicScene;

@end

static CVReturn renderCallback(CVDisplayLinkRef displayLink,
							   const CVTimeStamp *inNow,
							   const CVTimeStamp *inOutputTime,
							   CVOptionFlags flagsIn,
							   CVOptionFlags *flagsOut,
							   void *displayLinkContext)
{
    return [(__bridge OculusRiftSceneKitView *)displayLinkContext renderTime:inOutputTime];
}

@implementation OculusRiftSceneKitView

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithFrame:(CGRect)frame
{
    [self setupPixelFormat];
    self = [super initWithFrame:frame pixelFormat:[self pixelFormat]];
    NSAssert(self != nil, @"OpenGL pixel format not supported.");
    // TODO: user-friendly error handling
    
    [self commonInit];
    return self;
}

-(id)initWithCoder:(NSCoder *)coder
{
	if (!(self = [super initWithCoder:coder])) return nil;
    [self setupPixelFormat];
    [self commonInit];
	return self;
}

- (void)setupPixelFormat
{
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADepthSize, 24,
        0
    };
    [self setPixelFormat:[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes]];
    // TODO: fallback to an easier format if this one isn't available
    // caller deals with error handling
}

- (void)commonInit
{
    // initialize hardware
    [OculusRiftDevice getDevice];
    interpupillaryDistance = 64.0;
    
    // initialize OpenGL context
    [self setOpenGLContext:[[NSOpenGLContext alloc] initWithFormat:[self pixelFormat] shareContext:nil]];
    NSAssert([self openGLContext] != nil, @"Unable to create an OpenGL context.");
    // TODO: user-friendly error handling
    
    GLint swap = 0;
    [[self openGLContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];
    
    [[self openGLContext] makeCurrentContext];  // TODO: is this necessary? it was just created
    
    // create storage space for OpenGL textures
    glActiveTexture(GL_TEXTURE0);
    
    void (^setupBufferWithTexture)(GLuint*, GLuint*, GLuint*) = ^(GLuint* texture, GLuint* frameBuffer, GLuint* depthBuffer)
    {
        glGenTextures(1, texture);
        glBindTexture(GL_TEXTURE_2D, *texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glGenFramebuffers(1, frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, *frameBuffer);
        
        glGenRenderbuffers(1, depthBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, *depthBuffer);
        
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, EYE_RENDER_RESOLUTION_X, EYE_RENDER_RESOLUTION_Y);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, *depthBuffer);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, EYE_RENDER_RESOLUTION_X, EYE_RENDER_RESOLUTION_Y, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, *texture, 0);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete eye FBO: %d", status);
        
        glBindTexture(GL_TEXTURE_2D, 0);
    };
    setupBufferWithTexture(&leftEyeTexture, &leftEyeFramebuffer, &leftEyeDepthBuffer);
    setupBufferWithTexture(&rightEyeTexture, &rightEyeFramebuffer, &rightEyeDepthBuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    // connect shaders
    displayProgram = [[GLProgram alloc] initWithVertexShaderString:kOCVRVertexShaderString
                                              fragmentShaderString:kOCVRLensCorrectionFragmentShaderString];
    
    [displayProgram addAttribute:@"position"];
    [displayProgram addAttribute:@"inputTextureCoordinate"];
    
    if (![displayProgram link])
    {
        NSString *progLog = [displayProgram programLog];
        NSString *fragLog = [displayProgram fragmentShaderLog];
        NSString *vertLog = [displayProgram vertexShaderLog];
        
        NSLog(@"Program link log: %@", progLog);
        NSLog(@"Fragment shader compile log: %@", fragLog);
        NSLog(@"Vertex shader compile log: %@", vertLog);
        
        displayProgram = nil;
        NSAssert(NO, @"Filter shader link failed");
    }
    
    displayPositionAttribute = [displayProgram attributeIndex:@"position"];
    displayTextureCoordinateAttribute = [displayProgram attributeIndex:@"inputTextureCoordinate"];
    displayInputTextureUniform = [displayProgram uniformIndex:@"inputImageTexture"];
    
    screenCenterUniform = [displayProgram uniformIndex:@"ScreenCenter"];
    scaleUniform = [displayProgram uniformIndex:@"Scale"];
    scaleInUniform = [displayProgram uniformIndex:@"ScaleIn"];
    hmdWarpParamUniform = [displayProgram uniformIndex:@"HmdWarpParam"];
    lensCenterUniform = [displayProgram uniformIndex:@"LensCenter"];
    
    [displayProgram use];
    
    glEnableVertexAttribArray(displayPositionAttribute);
    glEnableVertexAttribArray(displayTextureCoordinateAttribute);
    
    // create a renderer for each eye
    SCNRenderer *(^makeEyeRenderer)() = ^
    {
        SCNRenderer *renderer = [SCNRenderer rendererWithContext:[[self openGLContext] CGLContextObj] options:nil];
        renderer.delegate = self;
        return renderer;
    };
    leftEyeRenderer  = makeEyeRenderer();
    rightEyeRenderer = makeEyeRenderer();
    
    // connect render callback
    CGDirectDisplayID displayID = CGMainDisplayID();
    CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    CVDisplayLinkSetOutputCallback(displayLink, renderCallback, (__bridge void *)self);
}

- (void)setScene:(SCNScene *)newScene
{
    CVDisplayLinkStop(displayLink);
    
    leftSceneReady = NO;
    rightSceneReady = NO;
    
    glUniform4f(hmdWarpParamUniform, 1.0, 0.22, 0.24, 0.0);
    
    leftEyeRenderer.scene = newScene;
    rightEyeRenderer.scene = newScene;
	if (![newScene isKindOfClass:[Scene class]])
	{
		CVDisplayLinkStart(displayLink);
		return;
	}
	Scene *scene = (Scene*)newScene;
	[Scene setCurrentScene:(Scene*)scene];
    
    // create cameras
    SCNNode *(^addNodeforEye)(int) = ^(int eye)
    {
        // TODO: read these from the HMD?
        CGFloat verticalFOV = 97.5;
        CGFloat horizontalFOV = 80.8;
        
        SCNCamera *camera = [SCNCamera camera];
        camera.xFov = 120;
        camera.yFov = verticalFOV;
        camera.zNear = horizontalFOV;
        camera.zFar = 2000;
        
        SCNNode *node = [SCNNode node];
        node.camera = camera;
        node.transform = [self getCameraTranslationForEye:eye];
        
        return node;
    };
    leftEyeRenderer.pointOfView = addNodeforEye(LEFT);
    rightEyeRenderer.pointOfView = addNodeforEye(RIGHT);
    [scene linkNodeToHeadRotation:leftEyeRenderer.pointOfView];
    [scene linkNodeToHeadRotation:rightEyeRenderer.pointOfView];
    
    CVDisplayLinkStart(displayLink);
}

- (void)renderStereoscopicScene
{
    static const GLfloat leftEyeVertices[] = {
        -1.0f, -1.0f,
         0.0f, -1.0f,
        -1.0f,  1.0f,
         0.0f,  1.0f,
    };
    
    static const GLfloat rightEyeVertices[] = {
        0.0f, -1.0f,
        1.0f, -1.0f,
        0.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    [displayProgram use];
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glViewport(0, 0, (GLint)self.bounds.size.width, (GLint)self.bounds.size.height);
    
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    
    glEnableVertexAttribArray(displayPositionAttribute);
    glEnableVertexAttribArray(displayTextureCoordinateAttribute);
    
    float w = 1.0;
    float h = 1.0;
    float x = 0.0;
    float y = 0.0;
    
    // Left eye
    float distortion = 0.151976 * 2.0;
    float scaleFactor = 0.583225;
    float as = 640.0 / 800.0;
    glUniform2f(scaleUniform, (w/2) * scaleFactor, (h/2) * scaleFactor * as);
    glUniform2f(scaleInUniform, (2/w), (2/h) / as);
    glUniform4f(hmdWarpParamUniform, 1.0, 0.22, 0.24, 0.0);
    glUniform2f(lensCenterUniform, x + (w + distortion * 0.5f)*0.5f, y + h*0.5f);
    glUniform2f(screenCenterUniform, x + w*0.5f, y + h*0.5f);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, leftEyeTexture);
    glUniform1i(displayInputTextureUniform, 0);
    glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, leftEyeVertices);
    glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // Right eye
    distortion = -0.151976 * 2.0;
    glUniform2f(lensCenterUniform, x + (w + distortion * 0.5f)*0.5f, y + h*0.5f);
    glUniform2f(screenCenterUniform, 0.5f, 0.5f);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, rightEyeTexture);
    glUniform1i(displayInputTextureUniform, 1);
    glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, rightEyeVertices);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    glDisableVertexAttribArray(displayPositionAttribute);
    glDisableVertexAttribArray(displayTextureCoordinateAttribute);
    
    rightSceneReady = NO;
    leftSceneReady = NO;
}

- (CVReturn)renderTime:(const CVTimeStamp *)timeStamp
{
    // use a background queue to avoid blocking the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [[Scene currentScene] tick:timeStamp];
        
        float x, y, z;
        [[OculusRiftDevice getDevice] getHeadRotationX:&x Y:&y Z:&z]; // update camera pose
        [[Scene currentScene] setHeadRotationX:x Y:y Z:z];
        
        [[self openGLContext] makeCurrentContext];
        [leftEyeRenderer render];
		glFinish();
		[rightEyeRenderer render];
		[rightEyeRenderer render];
		glFinish();
        [self renderStereoscopicScene];  // apply distortion
        [[self openGLContext] flushBuffer];
    });
    
    return kCVReturnSuccess;
}

- (void)dealloc
{
    [[OculusRiftDevice getDevice] shutdown];
    
    glDeleteFramebuffers(1, &leftEyeFramebuffer);
    glDeleteRenderbuffers(1, &leftEyeDepthBuffer);
    glDeleteTextures(1, &leftEyeTexture);
    glDeleteFramebuffers(1, &rightEyeFramebuffer);
    glDeleteRenderbuffers(1, &rightEyeDepthBuffer);
    glDeleteTextures(1, &rightEyeTexture);
    
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
}

#pragma mark -
#pragma mark SCNSceneRendererDelegate methods

- (void)renderer:(id <SCNSceneRenderer>)aRenderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
{
    if (aRenderer == leftEyeRenderer)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, leftEyeFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, leftEyeDepthBuffer);
        
        glViewport(0, 0, EYE_RENDER_RESOLUTION_X, EYE_RENDER_RESOLUTION_Y);
    }
    else if (aRenderer == rightEyeRenderer)
    {
        glBindFramebuffer(GL_FRAMEBUFFER, rightEyeFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, rightEyeDepthBuffer);
        
        glViewport(0, 0, EYE_RENDER_RESOLUTION_X, EYE_RENDER_RESOLUTION_Y);
    }
    
    glClearColor(redBackgroundComponent, greenBackgroundComponent, blueBackgroundComponent, alphaBackgroundComponent);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void)renderer:(id <SCNSceneRenderer>)aRenderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
{
    if (aRenderer == leftEyeRenderer)
    {
        if (rightSceneReady)
        {
            [self renderStereoscopicScene];
        }
        else
        {
            leftSceneReady = YES;
        }
    }
    else if (aRenderer == rightEyeRenderer)
    {
        if (leftSceneReady)
        {
            [self renderStereoscopicScene];
        }
        else
        {
            rightSceneReady = YES;
        }
    }
}

#pragma mark -
#pragma mark Accessors

- (CATransform3D)getCameraTranslationForEye:(int)eye
{
    // TODO: read IPD from HMD?
    float x = (-1 * eye) * (interpupillaryDistance/-2.0);
    return CATransform3DMakeTranslation(x, 0.0, 0.0);
}
- (void)setInterpupillaryDistance:(CGFloat)ipd;
{
    NSLog(@"IPD: %f", ipd);
    interpupillaryDistance = ipd;
    leftEyeCameraNode.transform = [self getCameraTranslationForEye:LEFT];
    rightEyeCameraNode.transform = [self getCameraTranslationForEye:RIGHT];
}

@end
