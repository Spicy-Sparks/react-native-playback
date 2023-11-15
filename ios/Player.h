#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>
#import <AVKit/AVKit.h>

@interface Player : NSObject

@property (nonatomic, strong, readonly) RCTEventEmitter *eventEmitter;
@property (nonatomic, strong, readonly) NSString *playerId;
@property (nonatomic, strong, readonly) AVPlayer *player;
@property (nonatomic, strong, readonly) AVPlayerItem *playerItem;
@property (nonatomic, strong, readonly) NSDictionary *source;
@property (nonatomic, assign, readonly) BOOL disposed;
@property (nonatomic, assign, readonly) BOOL loop;
@property (nonatomic, assign, readonly) BOOL paused;
@property (nonatomic, assign, readonly) BOOL playerObserversRegistered;
@property (nonatomic, assign, readonly) BOOL notficationCenterObserversRegistered;
@property (nonatomic, assign, readonly) BOOL playerItemObserversRegistered;
@property (nonatomic, strong, readonly) NSNumber *volume;
@property (nonatomic, strong) id timeObserver;

- (instancetype)initWithEventEmitterAndId:(RCTEventEmitter *)eventEmitter playerId:(NSString *)playerId;
- (void)setSource:(NSDictionary *)source;
- (void)setVolume:(NSNumber *)volume;
- (void)setLoop:(BOOL)loop;
- (void)seek:(NSDictionary *)seek;
- (void)play;
- (void)pause;
- (void)dispose;

@end
