#import "OculusRiftDevice.h"
#import <LibOVR/OVR_CAPI_GL.h>
#import <Extras/OVR_Math.h>

using namespace OVR;

@implementation OculusRiftDevice {
	ovrEyeRenderDesc eyeRenderDesc[2];
	NSSize textureSize[2];
}

@synthesize resolution;
@synthesize screen;
@synthesize hmd;  // ovrHmd_Create(0) or ovrHmd_CreateDebug(ovrHmd_DK2)
@synthesize isDebugHmd;

- (id)init
{
    if (!(self = [super init])) return nil;
    
    // initialize the SDK
    ovr_Initialize();
    
    // initialize the HMD
    hmd = ovrHmd_Create(0);
    if ((isDebugHmd = (hmd == nil)))
    {
        NSLog(@"WARNING: no HMD detected, faking it");
        hmd = ovrHmd_CreateDebug(ovrHmd_DK2);
    }
    NSLog(@"using HMD: %s %s", hmd->ProductName, hmd->SerialNumber);

	resolution = NSMakeSize(hmd->Resolution.w, hmd->Resolution.h);
	screen = nil;
	NSArray *screens = [NSScreen screens];
	if (screens.count > 1) {
		for (NSScreen *s in screens) {
			if (s == [NSScreen mainScreen]) continue;
			NSSize size = s.frame.size;
			if (size.width == resolution.width && size.height == resolution.height) {
				screen = s;
				break;
			}
		}
	}
	if (screen == nil) screen = [NSScreen mainScreen];

	[self configureSensor];
    
    return self;
}

+ (id)getDevice
{
	static OculusRiftDevice *device = nil;
	@synchronized(self)
	{
        if (device == nil)
            device = [[self alloc] init];
    }
	return device;
}

- (void)configureSensor
{
    // default: request all DK2 capabilities, but don't require them at startup
    // FUTURE: on new hardware, add its capabilities here
    unsigned int request = ovrTrackingCap_Orientation
    | ovrTrackingCap_MagYawCorrection
    | ovrTrackingCap_Position;
    unsigned int require = 0;
    [self configureSensorWithRequest:request andRequire:require];
}
- (void)configureSensorWithRequest:(unsigned int)request
                        andRequire:(unsigned int)require
{
    if (!ovrHmd_ConfigureTracking(hmd, request, require))
        NSLog(@"ERROR: no HMD with required caps %d", require);
    // TODO: error handling?
}

- (ovrTrackingState)getTrackingState
{
    return ovrHmd_GetTrackingState(hmd, ovr_GetTimeInSeconds());
}

- (SCNQuaternion)getHeadRotation
{
    // check for sensor data
    ovrTrackingState ts = [self getTrackingState];
    bool isTrackingHeadPose = ts.StatusFlags & (ovrStatus_OrientationTracked | ovrStatus_PositionTracked);
    if (!isTrackingHeadPose)
    {
        // TODO: popup warning for HMD out of camera range / unplugged
        //return CATransform3DMakeRotation(0, 0, 0, 0);
		return SCNVector4Zero;  // TODO: what's the actual starting value?
    }
    
    // fill x,y,z with converted sensor data
    Quatf pose = ts.HeadPose.ThePose.Orientation;
	return SCNVector4Make(pose.x, pose.y, pose.z, pose.w);
}

- (void)shutdown
{
    if (hmd)
        ovrHmd_Destroy(hmd);
    
    ovr_Shutdown();
}

- (const ovrEyeRenderDesc &)renderDescForEye:(ovrEyeType)eye
{
	return eyeRenderDesc[eye];
}

- (void)configureOpenGL
{
	eyeRenderDesc[ovrEye_Left] = ovrHmd_GetRenderDesc(hmd, ovrEye_Left, hmd->DefaultEyeFov[ovrEye_Left]);
	eyeRenderDesc[ovrEye_Right] = ovrHmd_GetRenderDesc(hmd, ovrEye_Right, hmd->DefaultEyeFov[ovrEye_Right]);
	
	ovrSizei size = ovrHmd_GetFovTextureSize(hmd, ovrEye_Left, eyeRenderDesc[ovrEye_Left].Fov, 1);
	textureSize[ovrEye_Left] = NSMakeSize(size.w, size.h);
	size = ovrHmd_GetFovTextureSize(hmd, ovrEye_Right, eyeRenderDesc[ovrEye_Right].Fov, 1);
	textureSize[ovrEye_Right] = NSMakeSize(size.w, size.h);
}

- (NSSize) recommendedTextureSizeForEye:(ovrEyeType)eye
{
	return textureSize[eye];
}

@end
