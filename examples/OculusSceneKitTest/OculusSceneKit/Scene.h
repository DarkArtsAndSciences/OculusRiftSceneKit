#import <SceneKit/SceneKit.h>

#import "MainWindow.h"

@interface Scene : SCNScene

@property CGFloat roomSize, avatarHeight, avatarSpeed;
@property SCNVector3 headPosition;

+ (id)currentScene;
+ (void)setCurrentScene:(Scene*)scene;

- (void)setHeadRotationX:(float)x Y:(float)y Z:(float)z;
- (void)linkNodeToHeadPosition:(SCNNode*)node;
- (void)linkNodeToHeadRotation:(SCNNode*)node;

- (void)tick:(const CVTimeStamp *)timeStamp;

- (BOOL)isInXZRange:(float)distance x:(float)x z:(float)z;

- (SCNLight*)makeAvatarSpotlight;
- (SCNLight*)makeAvatarOmnilight;
- (SCNNode*)makeWallWithMaterial:(SCNMaterial*)material
						  Width:(float)width
						 height:(float)height
							 Tx:(float)tx
							  y:(float)ty
							  z:(float)tz
						 Rangle:(float)rangle
							  x:(float)rx
							  y:(float)ry
							  z:(float)rz;
- (SCNNode*)makeCubeWithSize:(float)size
                     chamfer:(float)chamfer
                   materials:(NSArray*)materials
                    position:(SCNVector3)position;

- (void)addEventHandlersForStepWASD;
- (void)addEventHandlersForHoldWASD;
- (void)addEventHandlersForStepArrows;
- (void)addEventHandlersForHoldArrows;
- (void)addEventHandlersForLeftMouseDownMoveForward;
- (void)addEventHandlersForLeftMouseDownMoveBackward;
- (void)addEventHandlersForRightMouseDownMoveForward;
- (void)addEventHandlersForRightMouseDownMoveBackward;

- (void)addEventHandlerForType:(NSEventType)eventType
						  name:(NSString*)eventName
					   handler:(SEL)eventHandler;

- (void)resetEventHandlers;

- (NSMutableDictionary*)getHandlersForEventType:(NSEventType)eventType;

@end
