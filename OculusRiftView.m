//
//  OculusRiftView.m
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-05-28.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//

#import "OculusRiftView.h"
#import <OpenGL/gl.h>
#import "FrameBuffer.h"

void checkErrorAt(NSString*);

@interface OculusRiftView()
@property CVTimeStamp currentTime;
- (void) render;
@end

static CVReturn renderCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp *inNow,
                               const CVTimeStamp *inOutputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags *flagsOut,
                               void *displayLinkContext)
{
    OculusRiftView *view = (__bridge OculusRiftView *)displayLinkContext;
    view.currentTime = *inOutputTime;
    [view render];
    return kCVReturnSuccess;
}


@implementation OculusRiftView {
    OculusRiftDevice *hmd;
    SCNRenderer *leftEyeView;
    SCNRenderer *rightEyeView;
    SCNScene *scene;
    Avatar *avatar;
    NSMutableDictionary *eventHandlers;
    BOOL cursorHidden;
    CVDisplayLinkRef displayLink;
    NSMutableArray *sceneModifiers;
    dispatch_group_t renderGroup;
    dispatch_queue_t leftRenderQueue;
    dispatch_queue_t rightRenderQueue;
    dispatch_semaphore_t updateLock;
    BOOL updated;
}

@synthesize currentTime;

- (instancetype)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)format
{
    self = [super initWithFrame:frameRect pixelFormat:format];
    if (self == nil) return nil;
    cursorHidden = YES;
    [NSCursor hide];
    eventHandlers = [NSMutableDictionary dictionary];
    sceneModifiers = [NSMutableArray array];
    
    self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
    [self.openGLContext makeCurrentContext];
    hmd = [OculusRiftDevice getDevice];
    [hmd configureOpenGL:8];

    NSOpenGLContext *leftContext = [[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:self.openGLContext];
    leftEyeView = [SCNRenderer rendererWithContext:leftContext.CGLContextObj options:nil];
    [leftContext makeCurrentContext];
    leftEyeView.delegate = self;

    NSOpenGLContext *rightContext = [[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:self.openGLContext];
    rightEyeView = [SCNRenderer rendererWithContext:rightContext.CGLContextObj options:nil];
    [rightContext makeCurrentContext];
    rightEyeView.delegate = self;

    NSNumber *screenNumber = [hmd.screen.deviceDescription objectForKey:@"NSScreenNumber"];
    CGDirectDisplayID displayID = screenNumber.intValue;
    CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    CVDisplayLinkSetOutputCallback(displayLink, renderCallback, (__bridge void *)self);
    
    EventHandler *save = [EventHandler keyDownHandlerForKeyCode:1 modifiers:0 handler:^(NSEvent *event) {
        [self.openGLContext makeCurrentContext];
        NSImage *image = self.image;
        static unsigned int index = 0;
        NSBitmapImageRep *rep = [[image representations] objectAtIndex:0];
        NSData *data = [rep representationUsingType:NSPNGFileType properties: nil];
        NSString *filename = [[NSString stringWithFormat:@"~/Downloads/test%03d.png", index++] stringByExpandingTildeInPath];
        [data writeToFile: filename atomically:NO];
    }];
    [self registerEventHandler:save];
    
    renderGroup = dispatch_group_create();
    updateLock = dispatch_semaphore_create(1);
    leftRenderQueue = dispatch_queue_create("com.jma.OculusRiftPlayer.render.left", DISPATCH_QUEUE_SERIAL);
    rightRenderQueue = dispatch_queue_create("com.jma.OculusRiftPlayer.render.right", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (void)setScene:(SCNScene *)aScene
{
    scene = aScene;
    leftEyeView.scene = scene;
    rightEyeView.scene = scene;
}

- (void)setAvatar:(Avatar *)anAvatar
{
    avatar = anAvatar;
    leftEyeView.pointOfView = avatar.head.leftEye;
    rightEyeView.pointOfView = avatar.head.rightEye;
}

- (void)play:(id)sender
{
    CVDisplayLinkStart(displayLink);
}

- (void)stop:(id)sender
{
    CVDisplayLinkStop(displayLink);
}

- (void) registerSceneModifier:(SceneModifier)modifier
{
    [sceneModifiers addObject: modifier];
}

- (NSArray *)hitTest:(SCNVector3)point forEye:(EyeType)eye
{
    SCNRenderer *renderer = (eye == EyeType_Left) ? leftEyeView : rightEyeView;
    SCNVector3 screen = [renderer projectPoint:point];
    return [renderer hitTest:NSMakePoint(screen.x, screen.y) options:nil];
}

- (void) render
{
    updated = NO;
    [hmd prepareFrame];
    dispatch_group_async(renderGroup, leftRenderQueue, ^{
        [leftEyeView render];
    });
    dispatch_group_async(renderGroup, rightRenderQueue, ^{
        [rightEyeView render];
    });
    dispatch_group_wait(renderGroup, DISPATCH_TIME_FOREVER);
    [self.openGLContext makeCurrentContext];
    [hmd showFrame];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!CVDisplayLinkIsRunning(displayLink)) {
        [self.openGLContext makeCurrentContext];
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }
}

#pragma mark -
#pragma mark renderer delegate

- (EyeType) eyeForRenderer:(id<SCNSceneRenderer>)renderer
{
    if (renderer == leftEyeView)
        return EyeType_Left;
    return EyeType_Right;
}

- (void)renderer:(id<SCNSceneRenderer>)aRenderer updateAtTime:(NSTimeInterval)time
{
    dispatch_semaphore_wait(updateLock, DISPATCH_TIME_FOREVER);
    if (!updated) {
        for (SceneModifier modifier in sceneModifiers)
            modifier(currentTime);
        updated = YES;
        [hmd updateEyeNode:avatar.head.leftEye forEye:EyeType_Left];
        [hmd updateEyeNode:avatar.head.rightEye forEye:EyeType_Right];
    }
    dispatch_semaphore_signal(updateLock);
}

- (void)renderer:(id<SCNSceneRenderer>)aRenderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    CGLSetCurrentContext((CGLContextObj)aRenderer.context);
    EyeType eye = [self eyeForRenderer:aRenderer];
    [hmd bindFrameBufferForEye:eye];
}

- (void)renderer:(id<SCNSceneRenderer>)aRenderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    EyeType eye = [self eyeForRenderer:aRenderer];
    [hmd unbindFrameBufferForEye:eye];
}

#pragma mark -
#pragma mark Event handlers

- (void) registerEventHandler:(EventHandler*)handler
{
    if (handler == nil) return;
    NSNumber *eventType = [NSNumber numberWithInteger:handler.eventType];
    NSMutableArray *handlers = [eventHandlers objectForKey: eventType];
    if (handlers == nil)
        [eventHandlers setObject: [NSMutableArray arrayWithObject: handler] forKey: eventType];
    else [handlers addObject: handler];
}

- (void) handleEvent:(NSEvent *)theEvent
{
    NSNumber *eventType = [NSNumber numberWithInteger: theEvent.type];
    NSArray *handlers = [eventHandlers objectForKey: eventType];
    if (handlers != nil)
        for (EventHandler *handler in handlers) {
            if ([handler matchEvent:theEvent])
                handler.handler(theEvent);
        }
}

- (void) keyDown:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void) keyUp:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void) mouseDown:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void) rightMouseDown:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void) rightMouseUp:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void) rightMouseDragged:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    [self handleEvent: theEvent];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint mouseLoc = [NSEvent mouseLocation];
    if (NSPointInRect(mouseLoc, hmd.screen.frame)) {
        if (!cursorHidden) {
            [NSCursor hide];
            cursorHidden = YES;
        }
        [self handleEvent:theEvent];
    } else {
        if (cursorHidden) {
            [NSCursor unhide];
            cursorHidden = NO;
        }
    }
}

- (NSImage*) image
{
    NSSize size = self.frame.size;
    FrameBuffer *fb = [[FrameBuffer alloc] initWithSize:size];
    [self.openGLContext makeCurrentContext];
    [fb bind];
    [self render];
    [fb unbind];
    return fb.image;
}

@end
