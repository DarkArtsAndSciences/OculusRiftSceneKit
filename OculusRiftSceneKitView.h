#import <SceneKit/SceneKit.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "GLProgram.h"

#import "OculusRiftDevice.h"
#import "avatar.h"

@interface EventHandler : NSObject

@property (readonly) void (^handler)(NSEvent*);
@property (readonly) NSUInteger modifiers;
@property (readonly) NSEventType eventType;

- (id) initWithEventType: (NSEventType) type
			   modifiers: (NSUInteger) masks
				 handler: (void(^)(NSEvent*))aHandler;
- (BOOL) matchEvent: (NSEvent*) event;

+ (id) mouseDownEventWithModifiers:(NSUInteger) masks
							handler:(void (^)(NSEvent *))aHandler;

+ (id) mouseUpEventWithModifiers:(NSUInteger) masks
						  handler:(void (^)(NSEvent *))aHandler;

+ (id) mouseDragEventWithModifiers:(NSUInteger) masks
							handler:(void (^)(NSEvent *))aHandler;

+ (id) scrollWheelEventWithModifiers:(NSUInteger) masks
						   handler:(void (^)(NSEvent *))aHandler;
@end

@interface KeyEventHandler : EventHandler

@property (readonly) unsigned short keyCode;

- (id) initWithEventType: (NSEventType) type
				 keyCode: (unsigned short) key
			   modifiers:(NSUInteger)masks
				 handler:(void (^)(NSEvent *))aHandler;

- (BOOL) matchEvent:(NSEvent *)event;

+ (id) keyDownHandlerForKeyCode: (unsigned short) key
					  modifiers: (NSUInteger) masks
						handler: (void(^)(NSEvent*))aHandler;
+ (id) keyUpHandlerForKeyCode: (unsigned short) key
					modifiers: (NSUInteger) masks
					  handler: (void(^)(NSEvent*))aHandler;
@end

@interface OculusRiftSceneKitView : NSOpenGLView

// the eyeHeight and pivotToEyes are all measured in meters.
- (void)setScene:(SCNScene *)newScene
		  avatar:(Avatar*)avatar;

- (CVReturn)renderTime:(const CVTimeStamp *)timeStamp;
- (void) setUseNativeResolution: (BOOL) use;

- (IBAction) start: (id) sender;
- (IBAction) stop: (id) sender;

- (void) registerEventHandler:(EventHandler*) handler;
@end
