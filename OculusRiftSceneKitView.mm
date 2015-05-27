#import "OculusRiftSceneKitView.h"
#import "HolodeckScene.h"
#import <LibOVR/OVR_CAPI_GL.h>

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#define LEFT ovrEye_Left
#define RIGHT ovrEye_Right

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

BOOL checkModifiers(NSUInteger handler, NSUInteger event)
{
	if (handler == -1) return YES;
	if ((handler & NSShiftKeyMask) != (event & NSShiftKeyMask)) return NO;
	if ((handler & NSControlKeyMask) != (event &NSControlKeyMask)) return NO;
	if ((handler & NSAlternateKeyMask) != (event & NSAlternateKeyMask)) return NO;
	if ((handler & NSCommandKeyMask) != (event & NSCommandKeyMask)) return NO;
	return YES;
}

@implementation EventHandler

@synthesize handler;
@synthesize modifiers;
@synthesize eventType;

- (id) initWithEventType:(NSEventType)type
			   modifiers:(NSUInteger)masks
				 handler:(void (^)(NSEvent *))aHandler
{
	self = [super init];
	if (self == nil) return nil;
	handler = aHandler;
	eventType = type;
	modifiers = masks;
	return self;
}

+ (id) mouseDownEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSLeftMouseDown modifiers:masks handler:aHandler];
}

+ (id) mouseDragEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSLeftMouseDragged modifiers:masks handler:aHandler];
}

+ (id) mouseUpEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSLeftMouseUp modifiers:masks handler:aHandler];
}

+ (id)scrollWheelEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSScrollWheel modifiers:masks handler:aHandler];
}

- (BOOL) matchEvent:(NSEvent *)event
{
	return event.type == eventType && checkModifiers(modifiers, event.type);
}

@end

@implementation KeyEventHandler

@synthesize keyCode;

- (id)initWithEventType:(NSEventType)type
				keyCode:(unsigned short)key
			  modifiers:(NSUInteger)masks
				handler:(void (^)(NSEvent *))aHandler
{
	self = [super initWithEventType:type modifiers:masks handler:aHandler];
	if (self != nil) keyCode = key;
	return self;
}

- (BOOL)matchEvent:(NSEvent *)event
{
	if (event.type == NSKeyDown && event.ARepeat) return NO;
	return [super matchEvent:event] && event.keyCode == keyCode;
}

+ (id)keyDownHandlerForKeyCode:(unsigned short)key
					 modifiers:(NSUInteger)masks
					   handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSKeyDown
								   keyCode:key
								 modifiers:masks
								   handler:aHandler];
}

+ (id)keyUpHandlerForKeyCode:(unsigned short)key
				   modifiers:(NSUInteger)masks
					 handler:(void (^)(NSEvent *))aHandler
{
	return [[self alloc] initWithEventType:NSKeyUp
								   keyCode:key
								 modifiers:masks
								   handler:aHandler];
}

@end

@interface EyeRendererDelegate : NSObject<SCNSceneRendererDelegate>
{
	ovrSizei textureSize;
	GLuint renderBuffer;
	GLuint frameBuffer;
}

@property (readonly) GLuint texture;

- (id) initWithTextureSize: (NSSize) size;
- (void) setTextureSize: (NSSize) size;

- (void)renderer:(id <SCNSceneRenderer>)aRenderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
- (void)renderer:(id<SCNSceneRenderer>)aRenderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;

@end

@implementation EyeRendererDelegate

@synthesize texture;

-(id)initWithTextureSize:(NSSize)size
{
	self = [super init];
	if (self == nil) return nil;

	texture = 0;
	renderBuffer = 0;
	glGenFramebuffers(1, &frameBuffer);
	[self setTextureSize:size];
	return self;
}

- (void) dealloc
{
	glDeleteTextures(1, &texture);
	glDeleteRenderbuffers(1, &renderBuffer);
	glDeleteFramebuffers(1, &frameBuffer);
}

- (void)setTextureSize:(NSSize)size
{
	textureSize.w = size.width;
	textureSize.h = size.height;

	if (texture != 0) glDeleteTextures(1, &texture);
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, textureSize.w, textureSize.h, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);

	if (renderBuffer != 0) glDeleteRenderbuffers(1, &renderBuffer);
	glGenRenderbuffers(1, &renderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, textureSize.w, textureSize.h);
	
	glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete eye FBO: %d", status);
	glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)renderer:(id <SCNSceneRenderer>)aRenderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
	glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
	glViewport(0, 0, textureSize.w, textureSize.h);
	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void)renderer:(id<SCNSceneRenderer>)aRenderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glFlush();
}

@end

@interface OculusRiftSceneKitView()
{
	SCNScene *scene;
	Avatar *avatar;
    SCNRenderer *leftEyeRenderer, *rightEyeRenderer;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    GLint lensCenterUniform, screenCenterUniform, scaleUniform, scaleInUniform, hmdWarpParamUniform;
    
	BOOL useNativeResolution;
	EyeRendererDelegate *leftEyeDelegate;
	EyeRendererDelegate *rightEyeDelegate;
	
    CVDisplayLinkRef displayLink;

	// event handlers
	NSMutableDictionary *eventHandlers;
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
	eventHandlers = [NSMutableDictionary dictionary];
    // initialize OpenGL context
	NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:[self pixelFormat]
														  shareContext:nil];
	[self setOpenGLContext: context];
	NSOpenGLContext *leftContext = [[NSOpenGLContext alloc] initWithFormat:[self pixelFormat]
															  shareContext:context];
	NSOpenGLContext *rightContext = [[NSOpenGLContext alloc] initWithFormat:[self pixelFormat]
															   shareContext:context];
    NSAssert([self openGLContext] != nil, @"Unable to create an OpenGL context.");
    // TODO: user-friendly error handling
    
    GLint swap = 0;
    [[self openGLContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];

	leftEyeRenderer  = [SCNRenderer rendererWithContext:leftContext.CGLContextObj options:nil];
	rightEyeRenderer  = [SCNRenderer rendererWithContext:rightContext.CGLContextObj options:nil];
	leftEyeDelegate = nil;
	rightEyeDelegate = nil;

	[context makeCurrentContext];
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	[hmd configureOpenGL];

	[self setUseNativeResolution: NO];
}

- (void) prepareOpenGL
{
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
    
    // connect render callback
    CGDirectDisplayID displayID = CGMainDisplayID();
    CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    CVDisplayLinkSetOutputCallback(displayLink, renderCallback, (__bridge void *)self);

	glUniform4f(hmdWarpParamUniform, 1.0, 0.22, 0.24, 0.0);
}

- (void)setScene:(SCNScene *)aScene
		  avatar:(Avatar*)anAvatar
{
	BOOL running = CVDisplayLinkIsRunning(displayLink);
	[self stop:self];
	scene = aScene;
	
    leftEyeRenderer.scene = scene;
    rightEyeRenderer.scene = scene;

	avatar = anAvatar;
	leftEyeRenderer.pointOfView = avatar.head.leftEye;
	rightEyeRenderer.pointOfView = avatar.head.rightEye;
	if ([scene respondsToSelector:@selector(setAvatar:)]) {
		[scene performSelector:@selector(setAvatar:) withObject:avatar];
	} else [scene.rootNode addChildNode: avatar];
	if (running) [self start:self];
}

- (IBAction) start: (id) sender
{
	scene.paused = FALSE;
	CVDisplayLinkStart(displayLink);
}

- (IBAction) stop: (id) sender
{
	scene.paused = TRUE;
	CVDisplayLinkStop(displayLink);
}

- (void) drawRect:(NSRect)dirtyRect
{
	[self render];
}

- (void) setUseNativeResolution:(BOOL)use
{
	[self.openGLContext makeCurrentContext];
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	[hmd setUseNativeResolution: use];
	if (leftEyeDelegate == nil) {
		leftEyeDelegate = [[EyeRendererDelegate alloc] initWithTextureSize:[hmd textureSizeForEye:ovrEye_Left]];
		leftEyeRenderer.delegate = leftEyeDelegate;
	} else [leftEyeDelegate setTextureSize: [hmd textureSizeForEye: ovrEye_Left]];
	if (rightEyeDelegate == nil) {
		rightEyeDelegate = [[EyeRendererDelegate alloc] initWithTextureSize:[hmd textureSizeForEye:ovrEye_Right]];
		rightEyeRenderer.delegate = rightEyeDelegate;
	} else [rightEyeDelegate setTextureSize: [hmd textureSizeForEye: ovrEye_Right]];
}

- (void)renderStereoscopicScene
{
	[[self openGLContext] makeCurrentContext];
	static const GLfloat eyeVertices[2][8] = {{
        -1.0f, -1.0f,
         0.0f, -1.0f,
        -1.0f,  1.0f,
         0.0f,  1.0f
    }, {
        0.0f, -1.0f,
        1.0f, -1.0f,
        0.0f,  1.0f,
        1.0f,  1.0f
	}};
	
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f
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
    
	void (^renderEye)(ovrEyeType, GLuint) = ^(ovrEyeType eye, GLuint texture) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, texture);
		glUniform1i(displayInputTextureUniform, 0);
		glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, eyeVertices[eye]);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glBindTexture(GL_TEXTURE_2D, 0);
	};

    // Left eye
    float distortion = 0.151976 * 2.0;
    float scaleFactor = 0.583225;
    float as = 640.0 / 800.0;
    glUniform2f(scaleUniform, (w/2) * scaleFactor, (h/2) * scaleFactor * as);
    glUniform2f(scaleInUniform, (2/w), (2/h) / as);
    glUniform4f(hmdWarpParamUniform, 1.0, 0.22, 0.24, 0.0);
    glUniform2f(lensCenterUniform, x + (w + distortion * 0.5f)*0.5f, y + h*0.5f);
    glUniform2f(screenCenterUniform, x + w*0.5f, y + h*0.5f);
	glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
	renderEye(ovrEye_Left, leftEyeDelegate.texture);
	
    // Right eye
    distortion = -0.151976 * 2.0;
    glUniform2f(lensCenterUniform, x + (w + distortion * 0.5f)*0.5f, y + h*0.5f);
    glUniform2f(screenCenterUniform, 0.5f, 0.5f);
	renderEye(ovrEye_Right, rightEyeDelegate.texture);

    glDisableVertexAttribArray(displayPositionAttribute);
    glDisableVertexAttribArray(displayTextureCoordinateAttribute);
	[[self openGLContext] flushBuffer];
}

- (void) render {
	[avatar tick];
	if ([scene isKindOfClass: [HolodeckScene class]])
		[(HolodeckScene*)scene tick];
	
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	avatar.head.orientation = [hmd getHeadRotation];
	CGLSetCurrentContext((CGLContextObj)leftEyeRenderer.context);
	[leftEyeRenderer render];
	
	avatar.head.orientation = [hmd getHeadRotation];
	CGLSetCurrentContext((CGLContextObj)rightEyeRenderer.context);
	[rightEyeRenderer render];
	
	glFinish();
	[self renderStereoscopicScene];  // apply distortion
}

- (CVReturn)renderTime:(const CVTimeStamp *)timeStamp
{
    dispatch_async(dispatch_get_main_queue(), ^{
		[self render];
    });
    
    return kCVReturnSuccess;
}

- (void)dealloc
{
    [[OculusRiftDevice getDevice] shutdown];
    
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
}

#pragma mark -
#pragma mark Event handlers

- (void) registerEventHandler:(EventHandler*)handler
{
	if (handler == nil) return;
	NSNumber *eventType = [NSNumber numberWithInteger:handler.eventType];
	NSMutableArray *handlers = [eventHandlers objectForKey: eventType];
	if (handlers == nil)
		[eventHandlers setObject: [NSMutableArray arrayWithObject: handler] forKey: eventType];
	else [handlers addObject: handler];
}

- (void) handleEvent:(NSEvent *)theEvent
{
	NSNumber *eventType = [NSNumber numberWithInteger: theEvent.type];
	NSArray *handlers = [eventHandlers objectForKey: eventType];
	if (handlers == nil)
		NSLog(@"No event handler can handle event %lX", theEvent.type);
	else for (EventHandler *handler in handlers) {
		if ([handler matchEvent:theEvent])
			handler.handler(theEvent);
	}
}

- (void) keyDown:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

- (void) keyUp:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

- (void) mouseDown:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

 - (void)scrollWheel:(NSEvent *)theEvent
{
	[self handleEvent: theEvent];
}

@end
