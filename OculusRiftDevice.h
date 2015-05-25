#import <LibOVR/OVR_CAPI_0_5_0.h>
#import <SceneKit/SceneKit.h>

@interface OculusRiftDevice : NSObject

@property (assign, readonly) NSSize resolution;
@property (readonly) NSScreen *screen;
@property (assign, readonly) ovrHmd hmd;
@property (assign, readonly) bool   isDebugHmd;

+ (id)getDevice;

- (SCNQuaternion)getHeadRotation;
- (void)shutdown;
- (void) configureOpenGL;
- (const ovrEyeRenderDesc &) renderDescForEye: (ovrEyeType) eye;
- (NSSize) recommendedTextureSizeForEye: (ovrEyeType) eye;

@end
