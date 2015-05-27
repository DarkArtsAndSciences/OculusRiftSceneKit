#import <Cocoa/Cocoa.h>
#import "OculusRiftSceneKitView.h"

@interface SLSAppDelegate : NSObject <NSApplicationDelegate>

@property SCNScene *scene;
@property Avatar *avatar;

@property(assign) IBOutlet NSWindow *window;
@property(assign) IBOutlet OculusRiftSceneKitView *oculusView;

@end
