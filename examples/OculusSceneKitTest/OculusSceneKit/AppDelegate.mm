#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// load base scene with event handlers
	SCNScene *scene = [self getDefaultScene];

	// connect the view to the window
	[_window setContentView:self.oculusView];
	[_window makeFirstResponder:self.oculusView];

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
