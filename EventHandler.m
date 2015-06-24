//
//  EventHandler.m
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-05-28.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//

#import "EventHandler.h"

@interface KeyEventHandler : EventHandler

- (id) initWithEventType: (NSEventType) type
                 keyCode: (unsigned short) key
               modifiers:(NSUInteger)masks
                 handler:(void (^)(NSEvent *))aHandler;

- (BOOL) matchEvent:(NSEvent *)event;
@end

BOOL checkModifiers(NSUInteger handler, NSUInteger event)
{
    if (handler == -1) return YES;
    if ((handler & NSShiftKeyMask) != (event & NSShiftKeyMask)) return NO;
    if ((handler & NSControlKeyMask) != (event &NSControlKeyMask)) return NO;
    if ((handler & NSAlternateKeyMask) != (event & NSAlternateKeyMask)) return NO;
    if ((handler & NSCommandKeyMask) != (event & NSCommandKeyMask)) return NO;
    return YES;
}

@implementation EventHandler

@synthesize handler;
@synthesize modifiers;
@synthesize eventType;

- (id) initWithEventType:(NSEventType)type
               modifiers:(NSUInteger)masks
                 handler:(void (^)(NSEvent *))aHandler
{
    self = [super init];
    if (self == nil) return nil;
    handler = aHandler;
    eventType = type;
    modifiers = masks;
    return self;
}

+ (id) mouseDownEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSLeftMouseDown modifiers:masks handler:aHandler];
}

+ (id) mouseDraggedEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSLeftMouseDragged modifiers:masks handler:aHandler];
}

+ (id) mouseMovedEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSMouseMoved modifiers:masks handler:aHandler];
}

+ (id) mouseUpEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSLeftMouseUp modifiers:masks handler:aHandler];
}

+ (id) rightMouseDownEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSRightMouseDown modifiers:masks handler:aHandler];
}

+ (id) rightMouseUpEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSRightMouseUp modifiers:masks handler:aHandler];
}

+ (id) rightMouseDraggedEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSRightMouseDragged modifiers:masks handler:aHandler];
}

+ (id)scrollWheelEventWithModifiers:(NSUInteger)masks handler:(void (^)(NSEvent *))aHandler
{
    return [[self alloc] initWithEventType:NSScrollWheel modifiers:masks handler:aHandler];
}

- (BOOL) matchEvent:(NSEvent *)event
{
    return event.type == eventType && checkModifiers(modifiers, event.type);
}

+ (id)keyDownHandlerForKeyCode:(unsigned short)key
                     modifiers:(NSUInteger)masks
                       handler:(void (^)(NSEvent *))aHandler
{
    return [[KeyEventHandler alloc] initWithEventType:NSKeyDown
                                   keyCode:key
                                 modifiers:masks
                                   handler:aHandler];
}

+ (id)keyUpHandlerForKeyCode:(unsigned short)key
                   modifiers:(NSUInteger)masks
                     handler:(void (^)(NSEvent *))aHandler
{
    return [[KeyEventHandler alloc] initWithEventType:NSKeyUp
                                   keyCode:key
                                 modifiers:masks
                                   handler:aHandler];
}

@end

@implementation KeyEventHandler {
    unsigned short keyCode;
}

- (id)initWithEventType:(NSEventType)type
                keyCode:(unsigned short)key
              modifiers:(NSUInteger)masks
                handler:(void (^)(NSEvent *))aHandler
{
    self = [super initWithEventType:type modifiers:masks handler:aHandler];
    if (self != nil) keyCode = key;
    return self;
}

- (BOOL)matchEvent:(NSEvent *)event
{
    if (event.type == NSKeyDown && event.ARepeat) return NO;
    return [super matchEvent:event] && event.keyCode == keyCode;
}

@end
