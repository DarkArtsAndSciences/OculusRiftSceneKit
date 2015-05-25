#import "avatar.h"
#import "OculusRiftSceneKitView.h"
#import <Extras/OVR_Math.h>
using namespace OVR;


@interface Avatar (EventHandlers)
- (void)addEventHandlersForWASDToView: (OculusRiftSceneKitView*)view;
- (void)addEventHandlersForArrowToView: (OculusRiftSceneKitView*)view;
- (void)addEventHandlersForMouseToView: (OculusRiftSceneKitView*)view;
@end

@implementation Avatar
{
	SCNNode *headNode;
	NSTimeInterval eventTimeStamp;
	NSPoint lastMousePosition;
}

@synthesize moveDirection;
@synthesize speed;
@synthesize walkSpeed;
@synthesize runSpeed;
@synthesize turnSpeed;

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
		leftEyeRenderer:(SCNRenderer *)leftEyeRenderer
	   rightEyeRenderer:(SCNRenderer *)rightEyeRenderer
{
	if (!(self = [super init])) return nil;
	// default speed
	moveDirection = SCNVector3Make(0, 0, 0);
	walkSpeed = 1;
	runSpeed = 3;
	turnSpeed = M_PI*2;
	speed = 0;
	eventTimeStamp = [NSDate timeIntervalSinceReferenceDate];
	// head node
	headNode = [self makeHeadNodeWithEyeHeight:eyeHeight
								   pivotToEyes:pivotToEyes
							   leftEyeRenderer:leftEyeRenderer
							  rightEyeRenderer:rightEyeRenderer];
	[self addChildNode:headNode];
	[self load];
    return self;
}

// Register event handlers with the main window.
// Defaults are StepWASD and LeftMouseDownMoveForward.
- (void) addEventHandlersToView:(OculusRiftSceneKitView *)view
{
	// default event handlers
	[self addEventHandlersForWASDToView:view];
	[self addEventHandlersForArrowsToView:view];
	[self addEventHandlersForMouseToView:view];
}

#pragma mark - Avatar head rotation
- (SCNVector3) headRotation { return headNode.eulerAngles; }
- (void)setHeadRotation: (SCNQuaternion) rotation { headNode.orientation = rotation; }

- (SCNNode*)makeHeadNodeWithEyeHeight:(CGFloat)eyeHeight
						  pivotToEyes:(CGFloat)pivotToEyes
					  leftEyeRenderer:(SCNRenderer*)leftEyeRenderer
					 rightEyeRenderer:(SCNRenderer*)rightEyeRenderer;
{
	SCNNode *head = [SCNNode node];
	// create nodes for eye cameras and head sensors
	OculusRiftDevice *hmd = [OculusRiftDevice getDevice];
	self.position = SCNVector3Make(0, eyeHeight-pivotToEyes, 0);
	SCNNode *(^addNodeforEye)(ovrEyeType) = ^(ovrEyeType eye)
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
		[head addChildNode: node];
		return node;
	};
	leftEyeRenderer.pointOfView = addNodeforEye(ovrEye_Left);
	rightEyeRenderer.pointOfView = addNodeforEye(ovrEye_Right);
	return head;
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

- (BOOL)isMoving {
	return fabs(moveDirection.x)+fabs(moveDirection.y)+fabs(moveDirection.z) == 0 || speed == 0;
}

- (void)tick
{
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval dt = time - eventTimeStamp;
	self.position = SCNVector3Make(self.position.x + moveDirection.x * speed * dt,
								   self.position.y + moveDirection.y * speed * dt,
								   self.position.z + moveDirection.z * speed * dt);
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
    
	[headNode addChildNode:avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}

// Make an omnilight that automatically follows the user.
- (SCNLight*)makeAvatarOmnilight
{
	SCNLight *avatarLight = [SCNLight light];
    avatarLight.type = SCNLightTypeOmni;
    
    SCNNode *avatarLightNode = [SCNNode node];
    avatarLightNode.light = avatarLight;
    
	[headNode addChildNode: avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}

#pragma mark - Standard control schemes

- (void)addEventHandlersForWASDToView:(OculusRiftSceneKitView *)view
{
	[view registerKeyDownHandler:self
						  action:@selector(turnLeft:)
						  forKey:@"0"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(turnLeft:)
						  forKey:@"0"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(moveBackward:)
						  forKey: @"1"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(moveBackward:)
						  forKey: @"1"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(turnRight:)
						  forKey: @"2"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(turnRight:)
						  forKey: @"2"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(moveForward:)
						  forKey: @"13"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(moveForward:)
						  forKey: @"13"
				   withModifiers:NSShiftKeyMask];
	// stop
	[view registerKeyUpHandler:self
						action:@selector(stopMoving:)
						forKey:@"0"
				 withModifiers:-1];
	[view registerKeyUpHandler:self
						action:@selector(stopMoving:)
						forKey: @"1"
				 withModifiers:-1];
	[view registerKeyUpHandler:self
						action:@selector(stopMoving:)
						forKey: @"2"
				 withModifiers:-1];
	[view registerKeyUpHandler:self
						action:@selector(stopMoving:)
						forKey: @"13"
				 withModifiers:-1];
}

- (void)addEventHandlersForArrowsToView:(OculusRiftSceneKitView *)view
{
	[view registerKeyDownHandler:self
						  action:@selector(turnLeft:)
						  forKey:@"123"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(turnLeft:)
						  forKey:@"123"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(turnRight:)
						  forKey: @"124"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(turnRight:)
						  forKey: @"124"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(moveBackward:)
						  forKey: @"125"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(moveBackward:)
						  forKey: @"125"
				   withModifiers:NSShiftKeyMask];
	[view registerKeyDownHandler:self
						  action:@selector(moveForward:)
						  forKey: @"126"
				   withModifiers:0];
	[view registerKeyDownHandler:self
						  action:@selector(moveForward:)
						  forKey: @"126"
				   withModifiers:NSShiftKeyMask];
	// stop
	[view registerKeyUpHandler:self
						  action:@selector(stopMoving:)
						  forKey:@"123"
				   withModifiers:-1];
	[view registerKeyUpHandler:self
						  action:@selector(stopMoving:)
						  forKey: @"124"
				   withModifiers:-1];
	[view registerKeyUpHandler:self
						  action:@selector(stopMoving:)
						  forKey: @"125"
				   withModifiers:-1];
	[view registerKeyUpHandler:self
						action:@selector(stopMoving:)
						forKey: @"126"
				   withModifiers:-1];
}

- (void)addEventHandlersForMouseToView:(OculusRiftSceneKitView *)view
{
	[view registerMouseDownHandler:self
							action:@selector(mouseDown:)
					 withModifiers:0];
	[view registerMouseDownHandler:self
							action:@selector(mouseDown:)
					 withModifiers:NSShiftKeyMask];
	[view registerMouseDragHandler:self
							action:@selector(mouseDragged:)
					 withModifiers:0];
	[view registerMouseDragHandler:self
							action:@selector(mouseDragged:)
					 withModifiers:NSShiftKeyMask];
	// stop
	[view registerMouseUpHandler:self
						  action:@selector(stopMoving:)
				   withModifiers:-1];
}

//- (void)addEventHandlersForBothMouseDownMove  // TODO: both buttons at once
// TODO: QE turning
// TODO: defaults for space, return, esc?
// MAYBE: jump

#pragma mark - Event handlers

- (void)moveForward: (NSEvent*)event
{
	if (event.type == NSKeyDown && event.ARepeat) return;
	[self tick];
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	moveDirection = [self facing];
}

- (void)moveBackward: (NSEvent*)event
{
	[self tick];
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	SCNVector3 dir = [self facing];
	moveDirection = SCNVector3Make(-dir.x, -dir.y, -dir.z);
}

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

- (void)moveLeft: (NSEvent*)event
{
	[self tick];
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	moveDirection = rotateY([self facing], -M_PI/2);
}

- (void)moveRight: (NSEvent*)event
{
	[self tick];
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	moveDirection = rotateY([self facing], M_PI/2);
}

- (void)turnLeft: (NSEvent*)event
{
	NSTimeInterval dt = [NSDate timeIntervalSinceReferenceDate] - eventTimeStamp;
	[self rotateY: turnSpeed*dt];
	[self moveForward:event];
}

- (void)turnRight: (NSEvent*)event
{
	NSTimeInterval dt = [NSDate timeIntervalSinceReferenceDate] - eventTimeStamp;
	[self rotateY: -turnSpeed*dt];
	[self moveForward:event];
}

- (void)stopMoving: (NSEvent*)event
{
	[self tick];
	moveDirection = SCNVector3Make(0, 0, 0);
	lastMousePosition = [NSEvent mouseLocation];
}

- (void)mouseDown: (NSEvent*)event
{
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	lastMousePosition = [NSEvent mouseLocation];
	[self moveForward:event];
}

- (void)mouseDragged: (NSEvent*)event
{
	[self tick];
	if ([event modifierFlags] & NSShiftKeyMask)
		speed = runSpeed;
	else speed = walkSpeed;
	NSPoint pos = [NSEvent mouseLocation];
	CGFloat dx = (lastMousePosition.x - pos.x)/360*M_PI;
	[self rotateY: dx];
	[self moveForward:event];
	lastMousePosition = pos;
}

@end
