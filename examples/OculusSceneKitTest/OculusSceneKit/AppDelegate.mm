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

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// load base scene with event handlers
	SCNScene *scene = [self getDefaultScene];

	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	if (![hmd isDebugHmd]) // use full screen
	{
		// FUTURE: This assumes the HMD is the main screen, because the v0.4.1 Mac drivers don't support anything else.
		[_window setStyleMask: NSBorderlessWindowMask];
		NSRect screenRect = [[NSScreen mainScreen] frame];
		NSRect windowRect = NSMakeRect(0.0, 0.0, screenRect.size.width, screenRect.size.height);
		[_window setFrame:windowRect display:YES];		// window size and autoredraw subviews
		[_window setLevel:NSMainMenuWindowLevel+1];	// above the menu bar
		[_window setMovable:NO];						// not movable
		[_window setHidesOnDeactivate:NO];				// do NOT autohide when not front app
		//[self toggleFullScreen:nil];				// use own Space (10.7+)
	}
	// connect the view to the window
	[_window setContentView:self.oculusView];
	[_window makeFirstResponder:self.oculusView];
	[_window makeKeyAndOrderFront:self];
	// connect the scene to the view
	[self.oculusView setScene:scene];
	
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
