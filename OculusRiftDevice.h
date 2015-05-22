#import <LibOVR/OVR_CAPI_0_5_0.h>
#import <SceneKit/SceneKit.h>

@interface OculusRiftDevice : NSObject

@property (readonly) NSSize resolution;
@property (readonly) NSScreen *screen;
@property (assign, readonly) ovrHmd hmd;
@property (assign, readonly) bool   isDebugHmd;

+ (id)getDevice;

- (SCNVector3)getHeadRotation;
- (void)shutdown;

@end
