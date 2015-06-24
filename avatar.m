#import "avatar.h"
#import "OculusRiftDevice.h"

@implementation AvatarHead

@synthesize leftEye;
@synthesize rightEye;

-(id)init
{
	self = [super init];
	if (self == nil) return nil;
	// create nodes for eye cameras and head sensors
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	SCNNode *(^nodeForEye)(EyeType) = ^(EyeType eye)
	{
		SCNCamera *camera = [hmd cameraForEye:eye];
		SCNNode *node = [SCNNode node];
		node.camera = camera;
		// obviously the when we tilt our head, we should have a shift in eye position as well
		// here I move eyes up by an IPD, but I am not sure if this the the best way
		node.position = [hmd offsetForEye:eye];
		return node;
	};
	leftEye = nodeForEye(EyeType_Left);
	rightEye = nodeForEye(EyeType_Right);
	[self addChildNode:leftEye];
	[self addChildNode:rightEye];
	return self;
}

@end

@implementation Avatar
{
	NSTimeInterval eventTimeStamp;
	NSPoint lastMousePosition;
}

@synthesize velocity;
@synthesize angularVelocity;
@synthesize head;
@synthesize body;

#pragma mark - Initialization

- (id)initWithEyeHeight:(CGFloat)eyeHeight
{
	if (!(self = [super init])) return nil;
	// default speed
	velocity = SCNVector3Zero;
	eventTimeStamp = [NSDate timeIntervalSinceReferenceDate];
	// head node
	head = [self makeHead];
	head.position = SCNVector3Make(0, eyeHeight, 0);
	[self addChildNode:head];
	[self load];
    return self;
}

#pragma mark - Avatar head rotation

- (AvatarHead*)makeHead
{
	return [[AvatarHead alloc] init];
}

- (void) load
{
	// load file
	// TODO: code works, avatar.dae is broken?
	//NSURL *url = [NSURL URLWithString:@"file:///Path/to/file.dae"];
	//NSURL *url = [NSURL URLWithString:@"http://www.path.to/file.dae"];
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"avatar" withExtension:@"dae"];
	body = nil;
	if (url != nil) {
		SCNSceneSource *sceneSource = [[SCNSceneSource alloc]initWithURL:url options:nil];
		SCNScene *scene = [sceneSource sceneWithOptions: [NSDictionary dictionary] error: nil];
		if (scene != nil) body = [scene.rootNode clone];
	}
	if (body != nil) {
        body.position = SCNVector3Zero;
        body.name = @"avatarbody";
        [self addChildNode:body];
    }
}

- (SCNVector3) facing
{
	SCNVector3 angles = self.eulerAngles;
	SCNMatrix4 rot = SCNMatrix4MakeRotation(angles.y, 0, 1, 0);
    matrix_float4x4 m = SCNMatrix4ToMat4(rot);
    vector_float4 v = {0, 0, -1, 1};
    vector_float4 r = matrix_multiply(m, v);
    return SCNVector3Make(r.x, r.y, r.z);
}

#pragma mark - Avatar movement
// TODO: 2D turning, 3D movement (flying instead of walking)
// TODO: add diagonal 2D movement (add and normalize vectors)
// MAYBE: add XY WASD movement (locked to world, not direction facing)

- (void)tick
{
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	SCNQuaternion dir = [hmd getHeadRotation];
	head.orientation = dir;
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval dt = time - eventTimeStamp;
	self.position = SCNVector3Make(self.position.x + velocity.x * dt,
								   self.position.y + velocity.y * dt,
								   self.position.z + velocity.z * dt);
	[self rotateY: angularVelocity * dt];
	eventTimeStamp = time;
}

#pragma mark - Convenience functions for creating lights and objects

// Make a spotlight that automatically points wherever the user looks.
- (SCNLight*)makeAvatarSpotlight
{
	SCNLight *avatarLight = [SCNLight light];
    avatarLight.type = SCNLightTypeSpot;
    avatarLight.castsShadow = YES;
    
    SCNNode *avatarLightNode = [SCNNode node];
    avatarLightNode.light = avatarLight;
    
	[head addChildNode:avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}

// Make an omnilight that automatically follows the user.
- (SCNLight*)makeAvatarOmnilight
{
	SCNLight *avatarLight = [SCNLight light];
    avatarLight.type = SCNLightTypeOmni;
    
    SCNNode *avatarLightNode = [SCNNode node];
    avatarLightNode.light = avatarLight;
    
	[head addChildNode: avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}

#pragma mark - Standard control schemes

//- (void)addEventHandlersForBothMouseDownMove  // TODO: both buttons at once
// TODO: QE turning
// TODO: defaults for space, return, esc?
// MAYBE: jump

- (void) rotateY: (CGFloat) angle
{
	SCNVector3 angles = self.eulerAngles;
	self.eulerAngles = SCNVector3Make(angles.x, angles.y+angle, angles.z);
}

@end
