#import "Scene.h"
#import <Extras/OVR_Math.h>
using namespace OVR;

@implementation Scene
{
    SCNNode *headRotationNode, *headPositionNode;
    float hrx, hry, hrz;  // head rotation angles in radians
	
	NSMutableDictionary *keyDownHandlers, *keyUpHandlers, *mouseDownHandlers, *mouseUpHandlers;
    BOOL isMovingForward, isMovingBackward, isMovingLeft, isMovingRight;
}

@synthesize roomSize;
@synthesize avatarHeight;
@synthesize avatarSpeed;
@synthesize headPosition;

#pragma mark - Singleton

static Scene *currentScene = nil;
+ (id)currentScene
{
	@synchronized(self)
	{
        if (currentScene == nil)
            currentScene = [[self alloc] init];
    }
	return currentScene;
}
+ (void)setCurrentScene:(Scene*)scene
{
	@synchronized(self)
	{
		currentScene = scene;
		[scene resetEventHandlers];
		[scene addEventHandlers];
    }
}

#pragma mark - Initialization

- (id)init
{
    if (!(self = [super init])) return nil;
    
    // create nodes for eye cameras and head sensors
    headPositionNode = [SCNNode node];
    headPositionNode.position = SCNVector3Make(0, 0, 0);
    headRotationNode = [SCNNode node];
    [headPositionNode addChildNode:headRotationNode];
    [self.rootNode    addChildNode:headPositionNode];
	
	// default sizes
    roomSize = 1000;
	avatarHeight = 100;
	avatarSpeed = 1;
	
	[self resetEventHandlers];  // initialize handler storage
	[self stopMoving];  // set all isMovings to NO
	
    return self;
}

// Register event handlers with the main window.
// Defaults are StepWASD and LeftMouseDownMoveForward.
- (void) addEventHandlers
{
	// default event handlers
	[self addEventHandlersForStepWASD];
	[self addEventHandlersForStepArrows];
	[self addEventHandlersForLeftMouseDownMoveForward];
}

#pragma mark - Avatar head position and rotation

- (SCNVector3) headPosition { return headPositionNode.position; }  // position is public, node is private
- (void)setHeadPosition:(SCNVector3) position { headPositionNode.position = position; }

- (void)setHeadRotationX:(float)x Y:(float)y Z:(float)z
{
    hrx = x;
    hry = y;
    hrz = z;
    
    CATransform3D transform    =      CATransform3DMakeRotation(x, 0, 1, 0);
    transform                  = CATransform3DRotate(transform, y, 1, 0, 0);
    headRotationNode.transform = CATransform3DRotate(transform, z, 0, 0, 1);
}

- (void)linkNodeToHeadPosition:(SCNNode*)node { [headPositionNode addChildNode:node]; }
- (void)linkNodeToHeadRotation:(SCNNode*)node { [headRotationNode addChildNode:node]; }


#pragma mark - Avatar movement
// TODO: 2D turning, 3D movement (flying instead of walking)
// TODO: add diagonal 2D movement (add and normalize vectors)
// MAYBE: add XY WASD movement (locked to world, not direction facing)

- (BOOL)isMoving { return isMovingForward || isMovingBackward || isMovingLeft || isMovingRight; }
- (void)stopMoving
{
	isMovingForward  = NO;
	isMovingBackward = NO;
	isMovingRight    = NO;
	isMovingLeft     = NO;
}

- (void)startMovingForward  { isMovingForward  = YES; }
- (void)startMovingBackward { isMovingBackward = YES; }
- (void)startMovingLeft     { isMovingLeft     = YES; }
- (void)startMovingRight    { isMovingRight	   = YES; }

- (void)stopMovingForward   { isMovingForward  = NO; }
- (void)stopMovingBackward  { isMovingBackward = NO; }
- (void)stopMovingLeft      { isMovingLeft     = NO; }
- (void)stopMovingRight     { isMovingRight    = NO; }

- (void)tick:(const CVTimeStamp *)timeStamp
{
    if (isMovingForward)
        [self moveForward];
	else if (isMovingBackward)
		[self moveBackward];
	else if (isMovingLeft)
		[self moveLeft];
	else if (isMovingRight)
		[self moveRight];
}

- (void)moveForward		{ [self move2Direction: Vector3f( 0, 0,-1) distance:avatarSpeed]; }
- (void)moveBackward	{ [self move2Direction: Vector3f( 0, 0, 1) distance:avatarSpeed*0.75]; }
- (void)moveLeft		{ [self move2Direction: Vector3f(-1, 0, 0) distance:avatarSpeed*0.5]; }
- (void)moveRight		{ [self move2Direction: Vector3f( 1, 0, 0) distance:avatarSpeed*0.5]; }

- (void)stepForward		{ [self move2Direction: Vector3f( 0, 0,-1) distance:avatarSpeed*4]; }
- (void)stepBackward	{ [self move2Direction: Vector3f( 0, 0, 1) distance:avatarSpeed*3]; }
- (void)stepLeft		{ [self move2Direction: Vector3f(-1, 0, 0) distance:avatarSpeed*2]; }
- (void)stepRight		{ [self move2Direction: Vector3f( 1, 0, 0) distance:avatarSpeed*2]; }

- (void)runForward		{ [self move2Direction: Vector3f( 0, 0,-1) distance:avatarSpeed*10]; }
- (void)runBackward		{ [self move2Direction: Vector3f( 0, 0, 1) distance:avatarSpeed*7.5]; }
- (void)runLeft			{ [self move2Direction: Vector3f(-1, 0, 0) distance:avatarSpeed*5]; }
- (void)runRight		{ [self move2Direction: Vector3f( 1, 0, 0) distance:avatarSpeed*5]; }

- (BOOL)move2Direction:(Vector3f)direction
              distance:(float)distance
{
    return [self move2Direction:direction distance:distance facing:hrx];
}
- (BOOL)move2Direction:(Vector3f)direction  // in avatar space
              distance:(float)distance
                facing:(float)facing  // x rotation (yaw) in world space
{
    //NSLog(@"head position: %.2fx %.2fy %.2fz, moving %.2f radians * %.2f meters", self.headPosition.x, self.headPosition.y, self.headPosition.z, hrx, distance);
    
    Vector3f position = Vector3f(headPositionNode.position.x,
                                 headPositionNode.position.y,
                                 headPositionNode.position.z);
    
    Matrix4f rotate = Matrix4f::RotationY(facing);
    position += rotate.Transform(direction) * distance;

    headPositionNode.position = SCNVector3Make(position.x, position.y, position.z);
    
    //NSLog(@" new position: %.2fx %.2fy %.2fz", self.headPosition.x, self.headPosition.y, self.headPosition.z);
    // TODO: error handling, return NO if move failed
    return YES;
}

- (BOOL)isInXZRange:(float)distance x:(float)x z:(float)z
{
	Vector2f avatarXZ = Vector2f(self.headPosition.x, self.headPosition.z);  // ignore y
	return avatarXZ.Distance(Vector2f(x, z)) <= distance;
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
    
	[self linkNodeToHeadRotation:avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}
// Make an omnilight that automatically follows the user.
- (SCNLight*)makeAvatarOmnilight
{
	SCNLight *avatarLight = [SCNLight light];
    avatarLight.type = SCNLightTypeOmni;
    
    SCNNode *avatarLightNode = [SCNNode node];
    avatarLightNode.light = avatarLight;
    
	[self linkNodeToHeadPosition:avatarLightNode];
    
    return avatarLight; // caller can set light color, etc.
}

// Make and place a wall.
- (SCNNode*)makeWallWithMaterial:(SCNMaterial*)material
                      Width:(float)width
                     height:(float)height
                         Tx:(float)tx
                          y:(float)ty
                          z:(float)tz
                     Rangle:(float)rangle
                          x:(float)rx
                          y:(float)ry
                          z:(float)rz
{
    SCNPlane *wall = [SCNPlane planeWithWidth:width height:height];
    wall.materials = @[material];
    
    CATransform3D transform = CATransform3DMakeTranslation(tx, ty, tz);
    transform = CATransform3DRotate(transform, rangle, rx, ry, rz);
    
    SCNNode *node = [SCNNode nodeWithGeometry:wall];
    node.transform = transform;
    
    return node;
}

// Make and place a cube.
- (SCNNode*)makeCubeWithSize:(float)size
                     chamfer:(float)chamfer
                   materials:(NSArray*)materials
                    position:(SCNVector3)position
{
    SCNBox *box = [SCNBox boxWithWidth:size height:size length:size chamferRadius:chamfer];
    box.materials = materials;
    
    SCNNode *node = [SCNNode nodeWithGeometry:box];
    node.position = position;
    return node;
}

#pragma mark - Event handlers

- (void)resetEventHandlers
{
	keyDownHandlers = [NSMutableDictionary dictionary];
	keyUpHandlers = [NSMutableDictionary dictionary];
	mouseDownHandlers = [NSMutableDictionary dictionary];
	mouseUpHandlers = [NSMutableDictionary dictionary];
}

- (NSMutableDictionary*)getHandlersForEventType:(NSEventType)eventType
{
	NSMutableDictionary *handlers;
	if (eventType == NSKeyUp)
		handlers = keyUpHandlers;
	else if (eventType == NSKeyDown)
		handlers = keyDownHandlers;
	else if ((eventType == NSLeftMouseUp) || (eventType == NSRightMouseUp))
		handlers = mouseUpHandlers;
	else if ((eventType == NSLeftMouseDown) || (eventType == NSRightMouseDown))
		handlers = mouseDownHandlers;
	else
	{
		NSLog(@"tried to get event handlers for unrecognized event type %lu", (unsigned long)eventType);
		return nil;
	}
	return handlers;
}

#pragma mark - Standard control schemes

- (void)addEventHandlersForStepWASD
{
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepLeft)]		forKey: @"0"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runLeft)]		forKey:@"+0"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepBackward)]	forKey: @"1"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runBackward)]	forKey:@"+1"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepRight)]		forKey: @"2"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runRight)]		forKey:@"+2"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepForward)]	forKey: @"13"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runForward)]		forKey:@"+13"];
}

- (void)addEventHandlersForHoldWASD
{
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingLeft)]	 forKey: @"0"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingLeft)]		 forKey: @"0"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingBackward)] forKey: @"1"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingBackward)]  forKey: @"1"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingRight)]	 forKey: @"2"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingRight)]	 forKey: @"2"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingForward)]  forKey:@"13"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingForward)]   forKey:@"13"];
}

- (void)addEventHandlersForStepArrows
{
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepLeft)]		forKey: @"123"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runLeft)]		forKey:@"+123"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepRight)]		forKey: @"124"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runRight)]		forKey:@"+124"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepBackward)]	forKey: @"125"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runBackward)]	forKey:@"+125"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(stepForward)]	forKey: @"126"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(runForward)]		forKey:@"+126"];
}

- (void)addEventHandlersForHoldArrows
{
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingLeft)]	 forKey:@"123"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingLeft)]		 forKey:@"123"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingRight)]	 forKey:@"124"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingRight)]	 forKey:@"124"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingBackward)] forKey:@"125"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingBackward)]  forKey:@"125"];
	[keyDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingForward)]  forKey:@"126"];
	[keyUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingForward)]   forKey:@"126"];
}

- (void)addEventHandlersForLeftMouseDownMoveForward
{
	[mouseDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingForward)] forKey:@"left"];
	[mouseUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingForward)]  forKey:@"left"];
}
- (void)addEventHandlersForLeftMouseDownMoveBackward
{
	[mouseDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingForward)] forKey:@"left"];
	[mouseUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingForward)]  forKey:@"left"];
}
- (void)addEventHandlersForRightMouseDownMoveForward
{
	[mouseDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingForward)] forKey:@"right"];
	[mouseUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingForward)]  forKey:@"right"];
}
- (void)addEventHandlersForRightMouseDownMoveBackward
{
	[mouseDownHandlers setObject:[NSValue valueWithPointer:@selector(startMovingBackward)] forKey:@"right"];
	[mouseUpHandlers   setObject:[NSValue valueWithPointer:@selector(stopMovingBackward)]  forKey:@"right"];
}
//- (void)addEventHandlersForBothMouseDownMove  // TODO: both buttons at once
// TODO: QE turning
// TODO: defaults for space, return, esc?
// MAYBE: jump

#pragma mark - Custom controls

- (void)addEventHandlerForType:(NSEventType)eventType
						  name:(NSString*)eventName
					   handler:(SEL)eventHandler
{
	NSMutableDictionary *handlers = [self getHandlersForEventType:eventType];
	[handlers setObject:[NSValue valueWithPointer:eventHandler] forKey:eventName];
}

@end
