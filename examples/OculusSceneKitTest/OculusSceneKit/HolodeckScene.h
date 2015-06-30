#import "avatar.h"

@interface HolodeckScene : SCNScene

@property CGFloat roomSize;
@property (nonatomic) Avatar *avatar;

- (void) addEventHandlersToView: (id) view;
- (void) tick;
- (void) setAvatar:(Avatar *)anAvatar;
@end
