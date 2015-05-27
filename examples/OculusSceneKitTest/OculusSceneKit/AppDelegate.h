#import "OculusRiftSceneKitView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property Avatar *avatar;
@property SCNScene *scene;

@property CGFloat walkSpeed;
@property CGFloat runSpeed;
@property CGFloat turnSpeed;

@end
