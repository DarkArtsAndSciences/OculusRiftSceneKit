#import <SceneKit/SceneKit.h>

@interface Avatar : SCNNode

@property SCNVector3 moveDirection;
@property CGFloat speed;
@property CGFloat walkSpeed;
@property CGFloat runSpeed;
@property CGFloat turnSpeed;

- (id) initWithIPD: (CGFloat) ipd
		 eyeHeight: (CGFloat) eyeHeight
   leftEyeRenderer: (SCNRenderer*)leftEyeRenderer
  rightEyeRenderer: (SCNRenderer*)rightEyeRenderer;

- (SCNNode*) makeHeadNodeWithIPD: (CGFloat) ipd
					   eyeHeight: (CGFloat) eyeHeight
				 leftEyeRenderer: (SCNRenderer*)leftEyeRenderer
				rightEyeRenderer: (SCNRenderer*)rightEyeRenderer;
- (void)setHeadRotation:(SCNVector3)rotation;
- (SCNVector3)headRotation;
- (SCNVector3) facing;

- (void) load;

- (void)tick;

- (SCNLight*)makeAvatarSpotlight;
- (SCNLight*)makeAvatarOmnilight;

- (void) addEventHandlersToView: (id) view;
@end
