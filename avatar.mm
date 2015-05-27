#import "avatar.h"
#import "OculusRiftSceneKitView.h"
#import <Extras/OVR_Math.h>
using namespace OVR;

@implementation AvatarHead

@synthesize leftEye;
@synthesize rightEye;

-(id)initWithPivotToEyes:(CGFloat)pivotToEyes
{
	self = [super init];
	if (self == nil) return nil;
	// create nodes for eye cameras and head sensors
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	SCNNode *(^nodeForEye)(ovrEyeType) = ^(ovrEyeType eye)
	{
		Vector3f displace = [hmd renderDescForEye: eye].HmdToEyeViewOffset;
		FovPort fov = [hmd renderDescForEye: eye].Fov;
		// TODO: read these from the HMD?
		
		SCNCamera *camera = [SCNCamera camera];
		camera.xFov = fov.GetHorizontalFovDegrees();
		camera.yFov = fov.GetVerticalFovDegrees();
		camera.zNear = 0.01;
		camera.zFar = 1000;
		
		SCNNode *node = [SCNNode node];
		node.camera = camera;
		// obviously the when we tilt our head, we should have a shift in eye position as well
		// here I move eyes up by an IPD, but I am not sure if this the the best way
		node.position = SCNVector3Make(-displace.x, pivotToEyes, -0.05+displace.z);
		return node;
	};
	leftEye = nodeForEye(ovrEye_Left);
	rightEye = nodeForEye(ovrEye_Right);
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

#pragma mark - Initialization

- (SCNVector3) facing {
	Vector3f vec = Vector3f(0, 0, -1);
	SCNVector4 dir = self.orientation;
	Quatf rot = Quatf(dir.x, dir.y, dir.z, dir.w);
	vec = rot.Rotate(vec);
	return SCNVector3Make(vec.x, vec.y, vec.z);
}

- (id)initWithEyeHeight:(CGFloat)eyeHeight
			pivotToEyes:(CGFloat)pivotToEyes
{
	if (!(self = [super init])) return nil;
	// default speed
	velocity = SCNVector3Zero;
	eventTimeStamp = [NSDate timeIntervalSinceReferenceDate];
	// head node
	head = [self makeHeadWithPivotToEyes:pivotToEyes];
	head.position = SCNVector3Make(0, eyeHeight-pivotToEyes, 0);
	[self addChildNode:head];
	[self load];
    return self;
}

#pragma mark - Avatar head rotation

- (AvatarHead*)makeHeadWithPivotToEyes:(CGFloat)pivotToEyes
{
	return [[AvatarHead alloc] initWithPivotToEyes:pivotToEyes];
}

- (void) load
{
	// load file
	// TODO: code works, avatar.dae is broken?
	//NSURL *url = [NSURL URLWithString:@"file:///Path/to/file.dae"];
	//NSURL *url = [NSURL URLWithString:@"http://www.path.to/file.dae"];
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"avatar" withExtension:@"dae"];
	SCNSceneSource *sceneSource = [[SCNSceneSource alloc]initWithURL:url options:nil];
	SCNScene *scene = [sceneSource sceneWithOptions: [NSDictionary dictionary] error: nil];
	SCNNode *avatar = nil;
	if (scene == nil) {
		NSLog(@"  No nodes in DAE file");
		avatar = [SCNNode node];
	} else {
		avatar = [scene.rootNode clone];
		//NSLog(@"using node %@", node);
	}
	avatar.position = SCNVector3Zero;
	[self addChildNode:avatar];
}

#pragma mark - Avatar movement
// TODO: 2D turning, 3D movement (flying instead of walking)
// TODO: add diagonal 2D movement (add and normalize vectors)
// MAYBE: add XY WASD movement (locked to world, not direction facing)

- (void)tick
{
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

#pragma mark - Event handlers

SCNVector3 rotateY(SCNVector3 direction, CGFloat angle)
{
	CGFloat x=direction.x, y=direction.y;
	SCNVector3 dir = SCNVector3Make(cos(angle)*x-sin(angle)*y,
									sin(angle)*x+cos(angle)*y,
									0);
	return dir;
}

- (void) rotateY: (CGFloat) angle
{
	SCNVector4 orientation = self.orientation;
	Quatf quat = Quatf(orientation.x, orientation.y, orientation.z, orientation.w);
	Quatf rot = Quatf(Vector3f(0, 1, 0), angle);
	quat = Quatf(Matrix4f(rot)*Matrix4f(quat));
	self.orientation = SCNVector4Make(quat.x, quat.y, quat.z, quat.w);
}

@end
