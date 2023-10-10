#import "Player.h"
#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

@implementation Player

- (instancetype)initWithEventEmitter:(RCTEventEmitter *)eventEmitter {
    self = [super init];
    if (self) {
        _eventEmitter = eventEmitter;
        _playerId = [[NSUUID UUID] UUIDString];
        _player = [[AVPlayer alloc] init];
        _player.allowsExternalPlayback = true;
        _player.allowsAirPlayVideo = true;
        
        __weak __typeof(self) weakSelf = self;
        
        [_player addObserver:self forKeyPath:@"rate" options:0 context:nil];
        
        if(_timeObserver != nil)
            [_player removeTimeObserver:_timeObserver];
        _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            __typeof(self) strongSelf = weakSelf;
            if (strongSelf && strongSelf->_eventEmitter != nil) {
                [strongSelf->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": strongSelf->_playerId,
                    @"eventType": @"ON_PROGRESS",
                    @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(time)],
                    @"duration": [NSNumber numberWithFloat:CMTimeGetSeconds(strongSelf->_playerItem.duration)],
                }];
            }
        }];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:[_player currentItem]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStalled:) name:AVPlayerItemPlaybackStalledNotification object:nil];
        
        // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVPlayerAccess:) name:AVPlayerItemNewAccessLogEntryNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFailToFinishPlaying:) name: AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
            
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
            
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
            
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

- (void)disponse {
    if(_player != nil) {
        [_player pause];
        [_player removeObserver:self forKeyPath:@"rate"];
    }
    
    if(_timeObserver != nil) {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
    
    if(_playerItem != nil) {
        [_playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_playerItem removeObserver:self forKeyPath:@"status"];
        [_playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [_playerItem removeObserver:self forKeyPath:@"timedMetadata"];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setSource:(NSDictionary *)source {
    _source = source;
    
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    
    NSURL *url = [NSURL URLWithString:source[@"url"]];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{
        @"AVURLAssetHTTPHeaderFieldsKey": headers
    }];
    
    _playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [_playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"status" options:0 context:nil];
    [_playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:nil];
    [_playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:nil];
    [_playerItem addObserver:self forKeyPath:@"timedMetadata" options:NSKeyValueObservingOptionNew context:nil];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    [_player replaceCurrentItemWithPlayerItem:_playerItem];
    [_player play];
    [_player setVolume:1.0];

    /*AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
    playerViewController.player = _player;*/
}

- (void)play {
    if(_player == nil)
        return;
    [_player play];
}

- (void)pause {
    if(_player == nil)
        return;
    [_player pause];
}

- (void)setVolume:(NSNumber *)volume {
    if(_player == nil)
        return;
    [_player setVolume:[volume floatValue]];
}

- (void)seek:(NSDictionary *)seek
{
  NSNumber *time = seek[@"time"];
  NSNumber *tolerance = seek[@"tolerance"];
  
  int timeScale = 1000;
  
  AVPlayerItem *item = _player.currentItem;
  if (item && item.status == AVPlayerItemStatusReadyToPlay) {
      CMTime cmSeekTime = CMTimeMakeWithSeconds([time floatValue], timeScale);
      CMTime current = item.currentTime;
      CMTime cmTolerance = CMTimeMake([tolerance floatValue], timeScale);
    
      if (CMTimeCompare(current, cmSeekTime) != 0) {
          NSValue *seekTimeValue = [NSValue valueWithCMTime:cmSeekTime];
          NSValue *toleranceValue = [NSValue valueWithCMTime:cmTolerance];
          
          [_player seekToTime:cmSeekTime toleranceBefore:cmTolerance toleranceAfter:cmTolerance completionHandler:^(BOOL finished) {
              if(self->_eventEmitter != nil) {
                  [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": self->_playerId,
                    @"eventType": @"ON_SEEK",
                    @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(item.currentTime)],
                    @"seekTime": seekTimeValue
                  }];
              }
          }];
      }
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _player || object == _playerItem) {
        if([keyPath isEqualToString:@"rate"]) {
            if (_player.rate == 1.0) {
                if(_eventEmitter != nil) {
                    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": _playerId,
                        @"eventType": @"ON_PLAY"
                    }];
                }
            } else if (_player.rate == 0.0) {
                if(_eventEmitter != nil) {
                    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": _playerId,
                        @"eventType": @"ON_PAUSE"
                    }];
                }
            }
        }
        else if([keyPath isEqualToString:@"status"]) {
            if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
                if(_eventEmitter != nil) {
                    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": _playerId,
                        @"eventType": @"ON_LOAD"
                    }];
                }
            } else if (_playerItem.status == AVPlayerItemStatusFailed) {
                if(_eventEmitter != nil) {
                    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": _playerId,
                        @"eventType": @"ON_ERROR",
                        @"errorCode": [NSNumber numberWithInteger: _playerItem.error.code],
                        @"errorMessage": [_playerItem.error localizedDescription] == nil ? @"" : [_playerItem.error localizedDescription]
                    }];
                }
            }
        }
        else if([keyPath isEqualToString:@"timedMetadata"]) {
            if(_eventEmitter != nil) {
                [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": _playerId,
                    @"eventType": @"ON_TIMED_METADATA"
                }];
            }
        }
        else if([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            if(_eventEmitter != nil) {
                [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": _playerId,
                    @"eventType": @"ON_BUFFERING"
                }];
            }
        }
        else if([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            if(_eventEmitter != nil) {
                [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": _playerId,
                    @"eventType": @"ON_BUFFERING"
                }];
            }
        }
        else if([keyPath isEqualToString:@"loadedTimeRanges"]) {
            NSArray *timeRanges = [_playerItem.loadedTimeRanges valueForKey:@"CMTimeRangeValue"];
            CMTimeRange timeRange = [timeRanges.firstObject CMTimeRangeValue];
            float bufferingProgress = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
            if(_eventEmitter != nil) {
                [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": _playerId,
                    @"eventType": @"ON_BUFFERING",
                    @"progress": [NSNumber numberWithFloat:bufferingProgress]
                }];
            }
        }
    }
}

- (void)didFailToFinishPlaying:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    if(_eventEmitter != nil) {
        [_eventEmitter sendEventWithName:@"playerEvent" body:@{
            @"playerId": _playerId,
            @"eventType": @"ON_ERROR",
            @"errorCode": [NSNumber numberWithInteger: error.code],
            @"errorMessage": [error localizedDescription] == nil ? @"" : [error localizedDescription]
        }];
    }
}

- (void)playbackStalled:(NSNotification *)notification {
    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
        @"playerId": _playerId,
        @"eventType": @"ON_STALLED"
    }];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [_eventEmitter sendEventWithName:@"playerEvent" body:@{
        @"playerId": _playerId,
        @"eventType": @"ON_END"
    }];
}

- (void)audioRouteChanged:(NSNotification *)notification
{
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        case AVAudioSessionRouteChangeReasonOverride:
            if(_eventEmitter != nil) {
                [_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": _playerId,
                    @"eventType": @"ON_BECOME_NOISY"
                }];
            }
            break;
        default:
            break;

  }
}

@end
