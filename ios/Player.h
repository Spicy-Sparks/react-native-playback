#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>
#import <AVKit/AVKit.h>

@interface Player : NSObject

@property (nonatomic, strong, readonly) RCTEventEmitter *eventEmitter;
@property (nonatomic, strong, readonly) NSString *playerId;
@property (nonatomic, strong, readonly) AVPlayer *player;
@property (nonatomic, strong, readonly) AVPlayerItem *playerItem;
@property (nonatomic, strong, readonly) NSDictionary *source;
@property (nonatomic, strong) id timeObserver;

- (instancetype)initWithEventEmitterAndId:(RCTEventEmitter *)eventEmitter playerId:(NSString *)playerId;
- (void)setSource:(NSDictionary *)source;
- (void)setVolume:(NSNumber *)volume;
- (void)seek:(NSDictionary *)seek;
- (void)play;
- (void)pause;
- (void)disponse;

@end
