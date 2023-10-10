#import "Player.h"
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNPlaybackSpec.h"

@interface Playback : RCTEventEmitter <NativePlaybackSpec>
#else
#import <React/RCTBridgeModule.h>

@interface Playback : RCTEventEmitter <RCTBridgeModule>
#endif

@property (class, nonatomic, strong) NSMutableDictionary *players;

@end
