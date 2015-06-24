//
//  OpenGLTexture.m
//  OculusRiftPlayer
//
//  Created by Junling Ma on 2015-06-07.
//  Copyright (c) 2015 Junling.Ma. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "FrameBuffer.h"

void checkErrorAt(NSString *pos) {
    BOOL quit = NO;
    while (!quit) {
        GLenum err = glGetError();
        switch (err) {
            case GL_NO_ERROR:
                quit = YES;
                break;
            case GL_INVALID_VALUE:
                NSLog(@"Error at %@: invalid value", pos);
                break;
            case GL_INVALID_OPERATION:
                NSLog(@"Error at %@: invalid operation", pos);
                break;
            case GL_INVALID_FRAMEBUFFER_OPERATION:
                NSLog(@"Error at %@: invalid framebuffer operation", pos);
                break;
            case GL_INVALID_ENUM:
                NSLog(@"Error at %@: invalid enum", pos);
                break;
            default:
                NSLog(@"Error at %@: unknown error %d", pos, err);
        }
    }
}


@implementation FrameBuffer {
    GLuint renderBuffer;
    GLenum target;
}

@synthesize texture;
@synthesize frameBuffer;
@synthesize size;

- (instancetype)initWithSize:(NSSize)bufferSize
{
    self = [super init];
    if (self == nil) return self;
    texture = 0;
    frameBuffer = 0;
    renderBuffer = 0;
    target = GL_TEXTURE_2D;
    glGenTextures(1, &texture);
    glBindTexture(target, texture);
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glGenRenderbuffers(1, &renderBuffer);
    [self setSize:bufferSize];
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target, texture, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete eye FBO: %d", status);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return self;
}

- (void)setSize:(NSSize)bufferSize
{
    size = bufferSize;
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, size.width, size.height);

    glBindTexture(target, texture);
    glTexImage2D(target, 0, GL_RGBA, size.width, size.height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
}

- (void)dealloc
{
    if (texture > 0)
        glDeleteTextures(1, &texture);
    if (frameBuffer > 0)
        glDeleteFramebuffers(1, &frameBuffer);
    if (renderBuffer > 0)
        glDeleteRenderbuffers(1, &renderBuffer);
}

- (void) bind
{
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glViewport(0, 0, size.width, size.height);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void) unbind
{
    glFlush();
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void)bindTextureAtLocation:(size_t)location
{
    glActiveTexture(GL_TEXTURE0 + (int)location);
    glBindTexture(target, texture);
}

- (void)unbindTexture
{
    glBindTexture(target, 0);
}

- (NSImage*) image
{
    int length = (size.width*size.height*4);
    void *bytes = malloc(length);
    glBindTexture(target, texture);
    glGetTexImage(target, 0, GL_RGBA, GL_UNSIGNED_BYTE, bytes);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bitmapFormat: NSAlphaNonpremultipliedBitmapFormat bytesPerRow:size.width*4 bitsPerPixel:32];
    memcpy(rep.bitmapData, bytes, length);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image addRepresentation:rep];
    free(bytes);
    return image;
}
@end
