#import "AppDelegate.h"

@interface MainWindow : NSWindow
- (BOOL) canBecomeKeyWindow;
@end

@implementation MainWindow

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

@end

@implementation AppDelegate {
	MainWindow *window;
}

@synthesize avatar;
@synthesize scene;
@synthesize walkSpeed;
@synthesize runSpeed;
@synthesize turnSpeed;

- (instancetype)init
{
	self = [super init];
	if (self == nil) return nil;
	walkSpeed = 1;
	runSpeed = 3;
	turnSpeed = M_PI/2;
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// load base scene with event handlers
	scene = [self getDefaultScene];

	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	NSSize screenSize = hmd.screen.frame.size;
	NSRect frame;
	BOOL fullScreen = !hmd.isDebugHmd;
	frame.origin = NSMakePoint((screenSize.width-hmd.resolution.width)/2,
							   (screenSize.height-hmd.resolution.height)/2);
	frame.size = hmd.resolution;
	NSUInteger style = (fullScreen)? NSBorderlessWindowMask : NSTitledWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask ;
	window = [[MainWindow alloc] initWithContentRect:frame
													   styleMask:style
														 backing:NSBackingStoreBuffered
														   defer:YES
														  screen:hmd.screen];
	if (fullScreen) // use full screen
	{
		// FUTURE: This assumes the HMD is the main screen, because the v0.4.1 Mac drivers don't support anything else.
		[window setLevel:NSMainMenuWindowLevel+1];	// above the menu bar
		[window setMovable:NO];						// not movable
		[window setHidesOnDeactivate:NO];				// do NOT autohide when not front app
		//[self toggleFullScreen:nil];				// use own Space (10.7+)
	}
	
	// view
	OculusRiftSceneKitView *oculusView = [[OculusRiftSceneKitView alloc] initWithFrame: frame];
	// connect the scene to the view
	avatar = [[Avatar alloc] initWithEyeHeight:1.8 pivotToEyes: 0.1];
	[oculusView setScene:scene avatar:avatar];
	[self addEventHandlersToView: oculusView];

	// connect the view to the window
	[window setContentView:oculusView];
	[window makeFirstResponder:oculusView];
	[window makeKeyAndOrderFront:self];
	[oculusView start:self];
}

- (SCNScene*)getDefaultScene
{
	// get the class name of the default scene
	NSString *defaultSceneName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"Default scene"];
	NSAssert(defaultSceneName != nil, @"No default scene name in Info.plist.");
	
    // create the default scene
	Class defaultSceneClass = NSClassFromString(defaultSceneName);
	NSAssert(defaultSceneClass != nil, @"No class for default scene named %@ in Info.plist.", defaultSceneName);
	return [defaultSceneClass scene];
}

- (SCNScene*)loadSceneAtURL:(NSURL*)url {
    NSDictionary *options = @{SCNSceneSourceCreateNormalsIfAbsentKey : @YES};
    
    // Load and set the scene.
    NSError * __autoreleasing error;
    SCNScene *s = [SCNScene sceneWithURL:url options:options error:&error];
    if (scene) {
        return s;
    }
    else {
        NSLog(@"Problem loading scene from %@\n%@", url, [error localizedDescription]);
		return nil;
    }
}

SCNVector3 scaleVector(SCNVector3 direction, CGFloat scale)
{
	scale /= sqrt(direction.x*direction.x + direction.y*direction.y + direction.z*direction.z);
	return SCNVector3Make(direction.x*scale, direction.y*scale, direction.z*scale);
}

- (void)addEventHandlersToView:(OculusRiftSceneKitView *)view
{
	void (^moveForward)(NSEvent*) = ^(NSEvent* event) {
		CGFloat speed = (event.modifierFlags & NSShiftKeyMask)? runSpeed : walkSpeed;
		avatar.velocity = scaleVector([avatar facing], speed);
	};
	
	void (^moveBackward)(NSEvent*) = ^(NSEvent* event) {
		CGFloat speed = (event.modifierFlags & NSShiftKeyMask)? runSpeed : walkSpeed;
		avatar.velocity = scaleVector([avatar facing], -speed);
	};
	
	void (^turnLeft)(NSEvent*) = ^(NSEvent* event) {
		avatar.angularVelocity = turnSpeed;
	};
	
	void (^turnRight)(NSEvent*) = ^(NSEvent* event) {
		avatar.angularVelocity = -turnSpeed;
	};
	
	void (^stopMoving)(NSEvent*) = ^(NSEvent* event) {
		avatar.velocity = SCNVector3Zero;
	};
	
	void (^stopTurning)(NSEvent*) = ^(NSEvent* event) {
		avatar.angularVelocity = 0;
	};
	
	void (^scrollWheel)(NSEvent*) = ^(NSEvent* event) {
		SCNVector3 dir = scaleVector([avatar facing], -event.deltaY/100);
		SCNVector3 pos = avatar.position;
		avatar.position = SCNVector3Make(pos.x + dir.x, pos.y + dir.y, pos.z + dir.z);
		[avatar rotateY: event.deltaX/300*M_PI/2];
	};
	
	EventHandler *handler;
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 123 modifiers: 0 handler:turnLeft];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 123 modifiers: NSShiftKeyMask handler:turnLeft];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyUpHandlerForKeyCode: 123 modifiers: -1 handler:stopTurning];
	[view registerEventHandler:handler];
	
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 124 modifiers: 0 handler:turnRight];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 124 modifiers: NSShiftKeyMask handler:turnRight];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyUpHandlerForKeyCode: 124 modifiers: -1 handler:stopTurning];
	[view registerEventHandler:handler];
	
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 126 modifiers: 0 handler:moveForward];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 126 modifiers: NSShiftKeyMask handler:moveForward];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyUpHandlerForKeyCode: 126 modifiers: -1 handler:stopMoving];
	[view registerEventHandler:handler];
	
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 125 modifiers: 0 handler:moveBackward];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyDownHandlerForKeyCode: 125 modifiers: NSShiftKeyMask handler:moveBackward];
	[view registerEventHandler:handler];
	handler = [KeyEventHandler keyUpHandlerForKeyCode: 125 modifiers: -1 handler:stopMoving];
	[view registerEventHandler:handler];
	
	handler = [EventHandler scrollWheelEventWithModifiers:-1 handler:scrollWheel];
	[view registerEventHandler:handler];
}

@end
