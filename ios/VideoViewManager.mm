#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(VideoViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(playerId, NSString);
RCT_EXPORT_VIEW_PROPERTY(resizeMode, NSString);

@end
