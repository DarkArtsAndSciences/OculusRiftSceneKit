//
//  OculusRiftView.h
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-05-28.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OculusRiftDevice.h"
#import <SceneKit/SceneKit.h>
#import "avatar.h"
#import "EventHandler.h"

typedef void (^SceneModifier)(CVTimeStamp time);

@interface OculusRiftView : NSOpenGLView<SCNSceneRendererDelegate, EventHandlerView>

@property (readonly) NSImage *image;

- (instancetype)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format;
- (void) setScene: (SCNScene*) scene;
- (void) setAvatar: (Avatar*)avatar;
- (NSArray*) hitTest:(SCNVector3)point forEye:(EyeType)eye;
- (IBAction) play: (id) sender;
- (IBAction) stop: (id) sender;

- (void) registerSceneModifier:(SceneModifier)modifier;

@end
