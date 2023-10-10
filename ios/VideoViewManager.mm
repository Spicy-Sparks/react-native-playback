#import <React/RCTViewManager.h>
#import "VideoViewManager.h"
#import "Playback.h"
#import "VideoView.h"

@implementation VideoViewManager

RCT_EXPORT_MODULE(VideoViewManager)

- (UIView *)view {
    return [[VideoView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(playerId, NSString)

@end
