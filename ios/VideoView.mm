#import "VideoView.h"
#import <AVKit/AVKit.h>
#import "Playback.h"
#import "Player.h"

@implementation VideoView
{
    NSString *_playerId;
}

- (instancetype)init
{
    self = [super init];
    
    if(self) {
        _playerViewController = [[VideoViewController alloc] init];
        _notificationCenterObserversRegistered = false;
        _playerViewController.updatesNowPlayingInfoCenter = false;
        _playerViewController.allowsPictureInPicturePlayback = false;
        if (@available(iOS 16.0, *)) {
            _playerViewController.allowsVideoFrameAnalysis = false;
        }
        _playerViewController.view.frame = self.bounds;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        self->_notificationCenterObserversRegistered = true;
    }
    
    return self;
}

- (void)dealloc {
    if (self->_notificationCenterObserversRegistered) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
        self->_notificationCenterObserversRegistered = false;
    }
}

- (void)setPlayerId:(NSString *)playerId {
    _playerId = playerId;
    _player = [[Playback players] objectForKey:_playerId];
    
    if(_player == nil)
        return;
    
    _playerViewController.player = _player.player;
    
    UIViewController *viewController = nil;
    UIResponder *nextResponder = self;
    while (nextResponder != nil) {
        nextResponder = [nextResponder nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            viewController = (UIViewController *)nextResponder;
            break;
        }
    }
    
    // UIViewController *viewController = [self reactViewController];
    [viewController addChildViewController:_playerViewController];
    [self addSubview:_playerViewController.view];
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player.player];
    _playerLayer.frame = self.frame;
    [self.layer addSublayer:_playerLayer];
    
    NSLog(@"Received playerID: %@", playerId);
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if(_player == nil || _playerLayer == nil || _playerViewController == nil)
        return;
    
    [_playerLayer setPlayer:nil];
    [_playerViewController setPlayer:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if(_player == nil || _playerLayer == nil || _playerViewController == nil)
        return;
    
    [_playerLayer setPlayer:_player.player];
    [_playerViewController setPlayer:_player.player];
}

@end
