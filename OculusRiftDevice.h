#import <SceneKit/SceneKit.h>
#import "FrameBuffer.h"

typedef enum {
    EyeType_Left = 0,
    EyeType_Right = 1
} EyeType;

@interface OculusRiftDevice : NSObject

@property (assign, readonly) NSSize resolution;
@property (assign, readonly) bool isDebugHmd;
@property (readonly) NSScreen *screen;
@property (readonly) FrameBuffer *leftFrameBuffer;
@property (readonly) FrameBuffer *rightFrameBuffer;
@property BOOL logFrameRate;

+ (id)getDevice;

- (SCNQuaternion) getHeadRotation;
- (void) shutdown;
- (void) configureOpenGL:(int)multisample;
- (void) setUseNativeResolution: (BOOL) use;
- (SCNVector3) offsetForEye:(EyeType)eye;
- (SCNCamera*) cameraForEye:(EyeType)eye;
- (void) bindFrameBufferForEye:(EyeType)eye;
- (void) unbindFrameBufferForEye:(EyeType)eye;
- (void) recenter;

- (void) prepareFrame;
- (void) updateEyeNode:(SCNNode*)node forEye:(EyeType)eye;
- (void) showFrame;
@end
