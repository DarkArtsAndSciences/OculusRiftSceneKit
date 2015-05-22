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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// load base scene with event handlers
	SCNScene *scene = [self getDefaultScene];

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
	[oculusView setScene:scene];

	// connect the view to the window
	[window setContentView:oculusView];
	[window makeFirstResponder:oculusView];
	[window makeKeyAndOrderFront:self];
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
    SCNScene *scene = [SCNScene sceneWithURL:url options:options error:&error];
    if (scene) {
        return scene;
    }
    else {
        NSLog(@"Problem loading scene from %@\n%@", url, [error localizedDescription]);
		return nil;
    }
}

@end
