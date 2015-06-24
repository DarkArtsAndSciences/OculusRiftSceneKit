//
//  EventHandler.h
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-05-28.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//


#import <AppKit/AppKit.h>

@interface EventHandler : NSObject

@property (readonly) void (^handler)(NSEvent*);
@property (readonly) NSUInteger modifiers;
@property (readonly) NSEventType eventType;

- (id) initWithEventType: (NSEventType) type
               modifiers: (NSUInteger) masks
                 handler: (void(^)(NSEvent*))aHandler;
- (BOOL) matchEvent: (NSEvent*) event;

+ (id) mouseDownEventWithModifiers:(NSUInteger) masks
                           handler:(void (^)(NSEvent *))aHandler;

+ (id) rightMouseDownEventWithModifiers:(NSUInteger) masks
                           handler:(void (^)(NSEvent *))aHandler;

+ (id) mouseUpEventWithModifiers:(NSUInteger) masks
                         handler:(void (^)(NSEvent *))aHandler;

+ (id) rightMouseUpEventWithModifiers:(NSUInteger) masks
                                handler:(void (^)(NSEvent *))aHandler;

+ (id) mouseDraggedEventWithModifiers:(NSUInteger) masks
                           handler:(void (^)(NSEvent *))aHandler;

+ (id) mouseMovedEventWithModifiers:(NSUInteger) masks
                           handler:(void (^)(NSEvent *))aHandler;

+ (id) rightMouseDraggedEventWithModifiers:(NSUInteger) masks
                              handler:(void (^)(NSEvent *))aHandler;

+ (id) scrollWheelEventWithModifiers:(NSUInteger) masks
                             handler:(void (^)(NSEvent *))aHandler;

+ (id) keyDownHandlerForKeyCode: (unsigned short) key
                      modifiers: (NSUInteger) masks
                        handler: (void(^)(NSEvent*))aHandler;
+ (id) keyUpHandlerForKeyCode: (unsigned short) key
                    modifiers: (NSUInteger) masks
                      handler: (void(^)(NSEvent*))aHandler;
@end

@protocol EventHandlerView <NSObject>

- (void) registerEventHandler:(EventHandler*) handler;

@end

