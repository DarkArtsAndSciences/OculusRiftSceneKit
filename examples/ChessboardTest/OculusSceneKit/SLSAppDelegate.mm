#import "SLSAppDelegate.h"

@interface SCNScene (Avatar)

- (void) setAvatar:(Avatar*) avatar;

@end

@implementation SCNScene (Avatar)

- (void)setAvatar:(Avatar *)avatar
{
    SCNNode *scaler = [SCNNode node];
    scaler.scale = SCNVector3Make(100, 100, 100);
    [scaler addChildNode:avatar];
    scaler.position=SCNVector3Make(0, 300, 0);
    [self.rootNode addChildNode:scaler];
}

@end
@implementation SLSAppDelegate

@synthesize scene;
@synthesize avatar;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    scene = [SCNScene scene];
    
    SCNNode *objectsNode = [SCNNode node];
    [scene.rootNode addChildNode:objectsNode];
    
    objectsNode.scale = SCNVector3Make(0.1, 0.1, 0.1);
    objectsNode.position = SCNVector3Make(0, -100.0, 0.0);
    objectsNode.rotation = SCNVector4Make(1, 0, 0, -M_PI / 2.0);
    
    // Chess model is from the WWDC 2013 Scene Kit presentation
    SCNScene *chessboardScene = [SCNScene sceneWithURL:[[NSBundle mainBundle] URLForResource:@"chess" withExtension:@"dae"] options:nil error:nil];
    SCNNode *chessboardNode = [chessboardScene.rootNode childNodeWithName:@"Line01" recursively:YES];
    NSLog(@"Chess node: %@", chessboardNode);
    [objectsNode addChildNode:chessboardNode];
    
    // Create a diffuse light
	SCNLight *diffuseLight = [SCNLight light];
    diffuseLight.color = [NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.8 alpha:1.0];
    SCNNode *diffuseLightNode = [SCNNode node];
    diffuseLight.type = SCNLightTypeOmni;
    diffuseLightNode.light = diffuseLight;
	diffuseLightNode.position = SCNVector3Make(0.0, 1000.0, 300);
    [diffuseLight setAttribute:@4500 forKey:SCNLightAttenuationEndKey];
    [diffuseLight setAttribute:@500 forKey:SCNLightAttenuationStartKey];
	[scene.rootNode addChildNode:diffuseLightNode];
    
    avatar = [[Avatar alloc] initWithEyeHeight:1.8 pivotToEyes:0.1];
    [self.oculusView setScene:scene avatar:avatar];
    
    // Have this start in fullscreen so that the rendering matches up to the Oculus Rift
    [self.window toggleFullScreen:nil];
    [self.oculusView start: self];
}

@end
