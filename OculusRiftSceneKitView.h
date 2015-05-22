#import <SceneKit/SceneKit.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "GLProgram.h"

#import "OculusRiftDevice.h"
#import "avatar.h"

@interface OculusRiftSceneKitView : NSOpenGLView <SCNSceneRendererDelegate>

@property Avatar* avatar;

- (void)setScene:(SCNScene *)newScene;
- (CVReturn)renderTime:(const CVTimeStamp *)timeStamp;
- (void) registerKeyDownHandler:(id)handler
						 action:(SEL)action
						 forKey:(NSString*)key
				  withModifiers:(NSUInteger)mask;
- (void) registerKeyUpHandler:(id)handler
					   action:(SEL)action
					   forKey:(NSString*)key
				withModifiers:(NSUInteger)mask;
- (void) registerMouseDownHandler:(id)handler
						   action:(SEL)action
					withModifiers:(NSUInteger)mask;
- (void) registerMouseUpHandler:(id)handler
						 action:(SEL)action
				  withModifiers:(NSUInteger)mask;
- (void) registerMouseDragHandler:(id)handler
						   action:(SEL)action
					withModifiers:(NSUInteger)mask;
@end
