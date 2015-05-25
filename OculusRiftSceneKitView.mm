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

@interface EventHandler : NSObject

@property (readonly) id handler;
@property (readonly) SEL action;
@property (readonly) NSUInteger modifiers;

- (id) initWithHandler: (id) handler action: (SEL) action modifiers: (NSUInteger) modifiers;
- (void) actWithObject: (id)obj;

@end

@implementation EventHandler

@synthesize handler;
@synthesize action;
@synthesize modifiers;

- (id) initWithHandler:(id)aHandler action:(SEL)anAction modifiers:(NSUInteger)mods
{
	self = [super init];
	if (self != nil) {
		handler = aHandler;
		action = anAction;
		modifiers = mods;
	}
	return self;
}

- (void) actWithObject:(id)obj
{
	if (![handler respondsToSelector:action])
		NSLog(@"Cannot respond to action");
	[handler performSelector:action withObject:obj];
}

@end

@interface OculusRiftSceneKitView()
{
    SCNRenderer *leftEyeRenderer, *rightEyeRenderer;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;
    
    GLint lensCenterUniform, screenCenterUniform, scaleUniform, scaleInUniform, hmdWarpParamUniform;
    
	BOOL useNativeResolution;
    ovrTexture eyeTexture[2];
	GLuint eyeDepthTexture[2];
	GLuint eyeFramebuffer[2];
    GLuint eyeDepthBuffer[2];
    
    CVDisplayLinkRef displayLink;
    
	SCNScene *scene;

	// event handlers
	NSMutableDictionary *keyDownHandlers;
	NSMutableDictionary *keyUpHandlers;
	NSMutableArray *mouseDownHandlers;
	NSMutableArray *mouseUpHandlers;
	NSMutableArray *mouseDragHandlers;
}

- (void)setupPixelFormat;
- (void)commonInit;
- (void)initEventHandlers;
- (NSString*) keyCode: (NSEvent*) theEvent;
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

@synthesize avatar;

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

- (void) initEventHandlers
{
	mouseDownHandlers = [NSMutableArray array];
	mouseUpHandlers = [NSMutableArray array];
	mouseDragHandlers = [NSMutableArray array];
	keyDownHandlers = [NSMutableDictionary dictionary];
	keyUpHandlers = [NSMutableDictionary dictionary];
}

- (void)commonInit
{
    // initialize hardware
	[self initEventHandlers];
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

	// create a renderer for each eye
	SCNRenderer *(^makeEyeRenderer)(CGLContextObj) = ^(CGLContextObj context)
	{
		SCNRenderer *renderer = [SCNRenderer rendererWithContext:context options:nil];
		renderer.delegate = self;
		return renderer;
	};
	leftEyeRenderer  = makeEyeRenderer(leftContext.CGLContextObj);
	rightEyeRenderer = makeEyeRenderer(rightContext.CGLContextObj);
	ovrGLTexture *tex = (ovrGLTexture*)&eyeTexture[ovrEye_Left];
	tex->OGL.TexId = 0;
	tex = (ovrGLTexture*)&eyeTexture[ovrEye_Right];
	tex->OGL.TexId = 0;
	eyeDepthBuffer[0] = eyeDepthBuffer[1] = 0;
	useNativeResolution = NO;
	[context makeCurrentContext];
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	[hmd configureOpenGL];
}

- (void) prepareTextures
{
	// create storage space for OpenGL textures
	glActiveTexture(GL_TEXTURE0);
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	void (^setupTexture)(ovrEyeType) = ^(ovrEyeType eye) {
		NSSize size;
		if (useNativeResolution) {
			size = hmd.resolution;
			size.width /= 2;
		}
		else size = [hmd recommendedTextureSizeForEye:eye];
		ovrSizei oSize = {.w= (int)size.width, .h= (int)size.height};
		ovrRecti vp= {.Pos={.x = 0, .y=0}, .Size=oSize};
		eyeTexture[eye].Header.API = ovrRenderAPI_OpenGL;
		eyeTexture[eye].Header.TextureSize = oSize;
		eyeTexture[eye].Header.RenderViewport = vp;
		ovrGLTexture *tex = (ovrGLTexture*)&eyeTexture[eye];
		if (tex->OGL.TexId != 0) glDeleteTextures(1, &tex->OGL.TexId);
		glGenTextures(1, &tex->OGL.TexId);
		glBindTexture(GL_TEXTURE_2D, tex->OGL.TexId);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, oSize.w, oSize.h, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);
		
		if (eyeDepthBuffer[eye] != 0) glDeleteBuffers(1, &eyeDepthBuffer[eye]);
		glGenBuffers(1, &eyeDepthBuffer[eye]);
		glBindRenderbuffer(GL_RENDERBUFFER, eyeDepthBuffer[eye]);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, oSize.w, oSize.h);

		glBindFramebuffer(GL_FRAMEBUFFER, eyeFramebuffer[eye]);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, eyeDepthBuffer[eye]);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex->OGL.TexId, 0);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete eye FBO: %d", status);
		glBindTexture(GL_TEXTURE_2D, 0);
	};
	setupTexture(ovrEye_Left);
	setupTexture(ovrEye_Right);
}

- (void) prepareOpenGL
{
	glGenFramebuffers(2, eyeFramebuffer);
	[self prepareTextures];

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

- (void)setScene:(SCNScene *)newScene
   withEyeHeight:(CGFloat)eyeHeight
	 pivotToEyes:(CGFloat)pivotToEyes
{
	BOOL running = CVDisplayLinkIsRunning(displayLink);
	[self stop:self];
	scene = newScene;
	if ([scene isKindOfClass: [HolodeckScene class]])
		[(HolodeckScene*)scene addEventHandlersToView: self];
	
    leftEyeRenderer.scene = newScene;
    rightEyeRenderer.scene = newScene;

	avatar = [[Avatar alloc] initWithEyeHeight:eyeHeight
								   pivotToEyes:pivotToEyes];
	leftEyeRenderer.pointOfView = avatar.head.leftEye;
	rightEyeRenderer.pointOfView = avatar.head.rightEye;
	if ([newScene respondsToSelector:@selector(setAvatar:)]) {
		[newScene performSelector:@selector(setAvatar:) withObject:avatar];
	} else [newScene.rootNode addChildNode: avatar];
	[avatar addEventHandlersToView: self];
	if (running) [self start:self];
}

- (IBAction) start: (id) sender
{
	CVDisplayLinkStart(displayLink);
}

- (IBAction) stop: (id) sender
{
	CVDisplayLinkStop(displayLink);
}

- (void) drawRect:(NSRect)dirtyRect
{
	[self render];
}

- (void) setUseNativeResolution:(BOOL)use
{
	[self.openGLContext makeCurrentContext];
	useNativeResolution = use;
	if (eyeFramebuffer[0] != 0) [self prepareTextures];
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
    
	void (^renderEye)(ovrEyeType) = ^(ovrEyeType eye) {
		glActiveTexture(GL_TEXTURE0);
		ovrGLTexture *tex = (ovrGLTexture*)&eyeTexture[eye];
		glBindTexture(GL_TEXTURE_2D, tex->OGL.TexId);
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
	renderEye(ovrEye_Left);
	
    // Right eye
    distortion = -0.151976 * 2.0;
    glUniform2f(lensCenterUniform, x + (w + distortion * 0.5f)*0.5f, y + h*0.5f);
    glUniform2f(screenCenterUniform, 0.5f, 0.5f);
	renderEye(ovrEye_Right);

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
	glFinish();
	
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
    
    glDeleteFramebuffers(2, eyeFramebuffer);
    glDeleteRenderbuffers(2, eyeDepthBuffer);
	ovrGLTexture *tex = (ovrGLTexture*)&eyeTexture[ovrEye_Left];
    glDeleteTextures(1, &tex->OGL.TexId);
	tex = (ovrGLTexture*)&eyeTexture[ovrEye_Right];
	glDeleteTextures(1, &tex->OGL.TexId);
	
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
}

#pragma mark -
#pragma mark SCNSceneRendererDelegate methods

- (void)renderer:(id <SCNSceneRenderer>)aRenderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
{
	ovrEyeType eye = (aRenderer == leftEyeRenderer) ? ovrEye_Left : ovrEye_Right;
	ovrRecti vp = eyeTexture[eye].Header.RenderViewport;
	glBindFramebuffer(GL_FRAMEBUFFER, eyeFramebuffer[eye]);
	glBindRenderbuffer(GL_RENDERBUFFER, eyeDepthBuffer[eye]);
	glViewport(vp.Pos.x, vp.Pos.y, vp.Size.w, vp.Size.h);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void)renderer:(id<SCNSceneRenderer>)aRenderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

#pragma mark -
#pragma mark Event handlers

- (NSString*) keyCode: (NSEvent*) theEvent
{
	return [[NSNumber numberWithInt:[theEvent keyCode]] stringValue];
}

BOOL checkModifiers(NSUInteger handler, NSUInteger event)
{
	if (handler == -1) return YES;
	if ((handler & NSShiftKeyMask) != (event & NSShiftKeyMask)) return NO;
	if ((handler & NSControlKeyMask) != (event &NSControlKeyMask)) return NO;
	if ((handler & NSAlternateKeyMask) != (event & NSAlternateKeyMask)) return NO;
	if ((handler & NSCommandKeyMask) != (event & NSCommandKeyMask)) return NO;
	return YES;
}

- (void) handleKey: (NSEvent*)theEvent byHandlers: (NSDictionary*) handlerMap
{
	NSString *key = [self keyCode: theEvent];
	NSArray *handlers = [handlerMap objectForKey: key];
	if (handlers == nil)
		NSLog(@"no handler for key %@", key);
	else for (EventHandler *handler in handlers)
		if (checkModifiers(handler.modifiers, [theEvent modifierFlags]))
			[handler actWithObject: theEvent];
}

- (void) keyDown:(NSEvent *)theEvent
{
	[self handleKey: theEvent byHandlers: keyDownHandlers];
}

- (void) keyUp:(NSEvent *)theEvent
{
	[self handleKey: theEvent byHandlers: keyUpHandlers];
}

- (void) handleMouseEvent: (NSEvent*)theEvent byHandlers: (NSArray*) handlers
{
	for (EventHandler *handler in handlers)
		if (checkModifiers(handler.modifiers, [theEvent modifierFlags]))
			[handler actWithObject: theEvent];
}

- (void) mouseDown:(NSEvent *)theEvent
{
	if ([mouseDownHandlers count] == 0)
		NSLog(@"No mouse down handler");
	else [self handleMouseEvent: theEvent byHandlers: mouseDownHandlers];
}

- (void) mouseUp:(NSEvent *)theEvent
{
	if ([mouseUpHandlers count] == 0)
		NSLog(@"No mouse up handler");
	else [self handleMouseEvent: theEvent byHandlers: mouseUpHandlers];
}

- (void) mouseDragged:(NSEvent *)theEvent
{
	if ([mouseDragHandlers count] == 0)
		NSLog(@"No mouse drag handler");
	else [self handleMouseEvent: theEvent byHandlers: mouseDragHandlers];
}

- (void) registerKeyHandler:(id)handler
					 action:(SEL)action
					 forKey:(NSString *)key
				  modifiers:(NSUInteger)modifiers
					  inMap:(NSMutableDictionary*) handlerMap
{
	EventHandler *theHandler = [[EventHandler alloc] initWithHandler:handler
															  action:action
														   modifiers:modifiers];
	NSMutableArray *handlers = [handlerMap objectForKey: key];
	if (handlers == nil)
		[handlerMap setObject: [NSMutableArray arrayWithObject: theHandler] forKey: key];
	else [handlers addObject: theHandler];
}

- (void) registerKeyDownHandler:(id)handler
						 action:(SEL)action
						 forKey:(NSString*)key
					  withModifiers:(NSUInteger)modifiers
{
	[self registerKeyHandler:handler
					  action:action
					  forKey:key
				   modifiers:modifiers
					   inMap:keyDownHandlers];
}

- (void) registerKeyUpHandler:(id)handler
					   action:(SEL)action
					   forKey:(NSString*)key
				withModifiers:(NSUInteger)modifiers
{
	[self registerKeyHandler:handler
					  action:action
					  forKey:key
				   modifiers:modifiers
					   inMap:keyUpHandlers];
}

- (void) registerMouseHandler:(id)handler
					   action:(SEL)action
					modifiers:(NSUInteger)modifiers
				   inHandlers:(NSMutableArray*)handlers
{
	[handlers addObject: [[EventHandler alloc] initWithHandler:handler
														action:action
													 modifiers:modifiers]];
}

- (void) registerMouseDownHandler:(id)handler
						   action:(SEL)action
					withModifiers:(NSUInteger)modifiers
{
	[self registerMouseHandler:handler
						action:action
					 modifiers:modifiers
					inHandlers:mouseDownHandlers];
}

- (void) registerMouseUpHandler:(id)handler
						 action:(SEL)action
				  withModifiers:(NSUInteger)modifiers
{
	[self registerMouseHandler:handler
						action:action
					 modifiers:modifiers
					inHandlers:mouseUpHandlers];
}

- (void) registerMouseDragHandler:(id)handler
						   action:(SEL)action
					withModifiers:(NSUInteger)modifiers
{
	[self registerMouseHandler:handler
						action:action
					 modifiers:modifiers
					inHandlers:mouseDragHandlers];
}
@end
