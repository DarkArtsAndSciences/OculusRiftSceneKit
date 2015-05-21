#import "MainWindow.h"
#import "OculusRiftDevice.h"

@implementation MainWindow

#pragma mark - Initialization

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)aStyle
				  backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag
{	
	// if debug HMD, use windowed mode
	BOOL isFullscreen = ![[OculusRiftDevice getDevice] isDebugHmd];
	if (isFullscreen)
	{
		NSLog(@"HMD detected, using fullscreen mode");
		aStyle = aStyle & NSBorderlessWindowMask; // no window chrome
		bufferingType = NSBackingStoreBuffered;   // buffered
	}
    self = [super initWithContentRect:contentRect
							styleMask:aStyle
							  backing:bufferingType
								defer:flag];
    if (!self) return nil;
	
	if (isFullscreen)
	{
		// FUTURE: This assumes the HMD is the main screen, because the v0.4.1 Mac drivers don't support anything else.
		NSRect screenRect = [[NSScreen mainScreen] frame];
		NSRect windowRect = NSMakeRect(0.0, 0.0, screenRect.size.width, screenRect.size.height);
		[self setFrame:windowRect display:YES];		// window size and autoredraw subviews
		[self setLevel:NSMainMenuWindowLevel+1];	// above the menu bar
		[self setMovable:NO];						// not movable
		[self setHidesOnDeactivate:NO];				// do NOT autohide when not front app
		//[self toggleFullScreen:nil];				// use own Space (10.7+)
	}
	[self makeKeyAndOrderFront:self];				// show the window
	
    return self;
}

- (BOOL)canBecomeKeyWindow { return YES; }  // allow borderless window to receive key events

@end
