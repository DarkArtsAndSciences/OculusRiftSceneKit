#import "OculusRiftDevice.h"
#import <LibOVR/OVR_CAPI_GL.h>
#import <LibOVR/OVR_CAPI_0_5_0.h>

inline SCNQuaternion quatFromOVRQuatf(ovrQuatf q)
{
    SCNQuaternion quat = SCNVector4Make(q.x, q.y, q.z, q.w);
    return quat;
}

inline SCNVector3 vector3FromOVRVector3f(ovrVector3f q, CGFloat scale=1)
{
    SCNVector3 vec = SCNVector3Make(q.x*scale, q.y*scale, q.z*scale);
    return vec;
}


@implementation OculusRiftDevice {
	ovrEyeRenderDesc eyeRenderDesc[2];
    ovrVector3f eyeOffset[2];
    ovrPosef headPose[2];
    ovrTexture eyeTexture[2];
	BOOL useNativeResolution;
    ovrHmd hmd;
}

@synthesize resolution;
@synthesize screen;
@synthesize isDebugHmd;
@synthesize leftFrameBuffer;
@synthesize rightFrameBuffer;
@synthesize logFrameRate;

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

    resolution = (isDebugHmd)? [NSScreen mainScreen].frame.size : NSMakeSize(hmd->Resolution.w, hmd->Resolution.h);
	screen = nil;
	NSArray *screens = [NSScreen screens];
    for (NSScreen *s in screens) {
        NSDictionary *info = s.deviceDescription;
        NSNumber *i = [info objectForKey:@"NSScreenNumber"];
        if (i.intValue == hmd->DisplayId) {
            screen = s;
            break;
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
    ovrQuatf pose = ts.HeadPose.ThePose.Orientation;
	return SCNVector4Make(pose.x, pose.y, pose.z, pose.w);
}

- (void)shutdown
{
    if (hmd) ovrHmd_Destroy(hmd);
    ovr_Shutdown();
}

- (void)configureOpenGL:(int)multisample
{
    int caps = ovrHmd_GetEnabledCaps(hmd);
    caps &= ~ovrHmdCap_NoVSync;
    ovrHmd_SetEnabledCaps(hmd, caps);

    ovrGLConfig cfg;
    cfg.OGL.Header.API = ovrRenderAPI_OpenGL;
    cfg.OGL.Header.BackBufferSize = hmd->Resolution;
    cfg.OGL.Header.Multisample = multisample;
    caps = ovrDistortionCap_TimeWarp | ovrDistortionCap_Vignette;
    if (multisample > 1)
        caps |= ovrDistortionCap_HqDistortion;
    if (hmd->Type >= ovrHmd_DK2)
        caps |= ovrDistortionCap_Overdrive;
    ovrHmd_ConfigureRendering(hmd, &cfg.Config, caps, hmd->DefaultEyeFov, eyeRenderDesc);
    eyeOffset[0] = eyeRenderDesc[0].HmdToEyeViewOffset;
    eyeOffset[1] = eyeRenderDesc[1].HmdToEyeViewOffset;
    
    [self setUseNativeResolution:NO];
    ovrHmd_DismissHSWDisplay(hmd);
}

- (void)setUseNativeResolution:(BOOL)use
{
	useNativeResolution = use;
    NSSize textureSize[2];
	if (use) {
		textureSize[ovrEye_Left] = resolution;
		textureSize[ovrEye_Left].width /= 2;
		textureSize[ovrEye_Right] = textureSize[ovrEye_Left];
	} else {
		ovrSizei size = ovrHmd_GetFovTextureSize(hmd, ovrEye_Left, eyeRenderDesc[ovrEye_Left].Fov, 1);
		textureSize[ovrEye_Left] = NSMakeSize(size.w, size.h);
		size = ovrHmd_GetFovTextureSize(hmd, ovrEye_Right, eyeRenderDesc[ovrEye_Right].Fov, 1);
		textureSize[ovrEye_Right] = NSMakeSize(size.w, size.h);
	}
    leftFrameBuffer = [[FrameBuffer alloc] initWithSize:textureSize[ovrEye_Left]];
    rightFrameBuffer = [[FrameBuffer alloc] initWithSize:textureSize[ovrEye_Right]];

    void (^setupTextureForEye)(ovrGLTexture *, FrameBuffer *) = ^(ovrGLTexture *texture, FrameBuffer *buffer) {
        texture->OGL.Header.API = ovrRenderAPI_OpenGL;
        texture->OGL.Header.TextureSize.w = buffer.size.width;
        texture->OGL.Header.TextureSize.h = buffer.size.height;
        texture->OGL.Header.RenderViewport.Pos.x = 0;
        texture->OGL.Header.RenderViewport.Pos.y = 0;
        texture->OGL.Header.RenderViewport.Size.w = buffer.size.width;
        texture->OGL.Header.RenderViewport.Size.h = buffer.size.height;
        texture->OGL.TexId = buffer.texture;
    };
    setupTextureForEye((ovrGLTexture*)&eyeTexture[0], leftFrameBuffer);
    setupTextureForEye((ovrGLTexture*)&eyeTexture[1], rightFrameBuffer);
}

- (SCNVector3)offsetForEye:(EyeType)eye
{
    ovrVector3f offset = eyeRenderDesc[eye].HmdToEyeViewOffset;
    return SCNVector3Make(-offset.x, -offset.y, -offset.z);
}

- (void) recenter
{
    ovrHmd_RecenterPose(hmd);
}

- (void)prepareFrame
{
    ovrHmd_BeginFrame(hmd, 0);
}

-(void)showFrame
{
    ovrHmd_EndFrame(hmd, headPose, eyeTexture);
    if (!logFrameRate) return;
    static int count = -1;
    static NSTimeInterval start;
    if (count == -1) {
        count = 0;
        start = [NSDate timeIntervalSinceReferenceDate];
    } else {
        count ++;
        if (count == 300) {
            NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
            NSLog(@"frame rate: %0.2lf", count / (time-start));
            start = time;
            count = 0;
        }
    }
}

- (void)updateEyeNode:(SCNNode *)node forEye :(EyeType)eye
{
    headPose[eye] = ovrHmd_GetHmdPosePerEye(hmd, (ovrEyeType)eye);
    SCNQuaternion quat = quatFromOVRQuatf(headPose[eye].Orientation);
    node.orientation = quat;
    SCNVector3 position = vector3FromOVRVector3f(headPose[eye].Position);
    node.position = position;
}

- (void) bindFrameBufferForEye:(EyeType)eye
{
    if (eye == EyeType_Left)
        [leftFrameBuffer bind];
    else [rightFrameBuffer bind];
    glClearColor(0, 0, 0, 0);
    glClearDepth(1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void)unbindFrameBufferForEye:(EyeType)eye
{
    if (eye == EyeType_Left)
        [leftFrameBuffer unbind];
    else [rightFrameBuffer unbind];
}

- (SCNCamera*)cameraForEye:(EyeType)eye
{
    ovrMatrix4f proj = ovrMatrix4f_Projection(eyeRenderDesc[eye].Fov, 0.01, 1000, ovrProjection_RightHanded | ovrProjection_ClipRangeOpenGL);
    SCNMatrix4 m;
    CGFloat *p = &m.m11;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            *p++ = proj.M[j][i];
    SCNCamera *camera = [SCNCamera camera];
    camera.projectionTransform = m;
    return camera;
}
@end
