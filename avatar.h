#import <SceneKit/SceneKit.h>

@interface AvatarHead : SCNNode

@property (readonly) SCNNode *leftEye;
@property (readonly) SCNNode *rightEye;

- (id) initWithPivotToEyes:(CGFloat)pivotToEyes;

@end

@interface Avatar : SCNNode

@property SCNVector3 velocity;
@property CGFloat angularVelocity;
@property (readonly) AvatarHead *head;

- (id) initWithEyeHeight:(CGFloat)eyeHeight
			 pivotToEyes:(CGFloat)pivotToEyes;

- (AvatarHead*) makeHeadWithPivotToEyes:(CGFloat)pivotToEyes;

- (SCNVector3)facing;
- (void) rotateY:(CGFloat)angle;
- (void) load;

- (void)tick;

- (SCNLight*)makeAvatarSpotlight;
- (SCNLight*)makeAvatarOmnilight;

@end
