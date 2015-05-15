#import <LibOVR/OVR_CAPI_0_5_0.h>

@interface OculusRiftDevice : NSObject

@property (assign, readonly) ovrHmd hmd;
@property (assign, readonly) bool   isDebugHmd;

+ (id)getDevice;

- (void)getHeadRotationX:(float*)x Y:(float*)y Z:(float*)z;
- (void)shutdown;

@end
