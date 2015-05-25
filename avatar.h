#import <SceneKit/SceneKit.h>

@interface AvatarHead : SCNNode

@property (readonly) SCNNode *leftEye;
@property (readonly) SCNNode *rightEye;

- (id) initWithPivotToEyes:(CGFloat)pivotToEyes;

@end

@interface Avatar : SCNNode

@property SCNVector3 moveDirection;
@property CGFloat speed;
@property CGFloat walkSpeed;
@property CGFloat runSpeed;
@property CGFloat turnSpeed;
@property (readonly) AvatarHead *head;

- (id) initWithEyeHeight:(CGFloat)eyeHeight
			 pivotToEyes:(CGFloat)pivotToEyes;

- (AvatarHead*) makeHeadWithPivotToEyes:(CGFloat)pivotToEyes;

- (SCNVector3)facing;
- (void) load;

- (void)tick;

- (SCNLight*)makeAvatarSpotlight;
- (SCNLight*)makeAvatarOmnilight;

- (void) addEventHandlersToView: (id) view;
@end
