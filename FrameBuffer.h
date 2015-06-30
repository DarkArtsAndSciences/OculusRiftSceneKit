//
//  OpenGLTexture.h
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-06-07.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>

@interface FrameBuffer : NSObject

@property (readonly) GLuint texture;
@property (readonly) GLuint frameBuffer;
@property (readonly) NSSize size;
@property (readonly) NSImage *image;

- (instancetype)initWithSize:(NSSize)bufferSize;
- (void) setSize:(NSSize)bufferSize;
- (void) bind;
- (void) unbind;
- (void) bindTextureAtLocation:(size_t)location;
- (void) unbindTexture;
@end
