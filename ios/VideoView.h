#import "VideoViewController.h"
#import "Player.h"

@interface VideoView : UIView

@property (nonatomic, strong, readonly) Player *player;
@property (nonatomic, strong, readonly) VideoViewController *playerViewController;
@property (nonatomic, strong, readonly) AVPlayerLayer *playerLayer;

@end
