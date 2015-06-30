#import <SceneKit/SceneKit.h>

@interface AvatarHead : SCNNode

@property (readonly) SCNNode *leftEye;
@property (readonly) SCNNode *rightEye;

- (id) init;
@end

@interface Avatar : SCNNode

@property SCNVector3 velocity;
@property CGFloat angularVelocity;
@property (readonly) AvatarHead *head;
@property (readonly) SCNNode *body;

- (id) initWithEyeHeight:(CGFloat)eyeHeight;

- (AvatarHead*) makeHead;

- (SCNVector3)facing;
- (void)rotateY:(CGFloat)angle;
- (void)load;

- (void)tick;

- (SCNLight*)makeAvatarSpotlight;
- (SCNLight*)makeAvatarOmnilight;

@end
