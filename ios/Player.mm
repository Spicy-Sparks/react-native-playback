#import "Player.h"
#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

@implementation Player

- (instancetype)initWithEventEmitterAndId:(RCTEventEmitter *)eventEmitter playerId:(NSString *)playerId {
    self = [super init];
    if (self) {
        _disposed = false;
        _playerObserversRegistered = false;
        _notficationCenterObserversRegistered = false;
        _currentItemObserversRegistered = false;
        _eventEmitter = eventEmitter;
        _playerId = playerId;
        _player = [[AVPlayer alloc] init];
        _player.allowsExternalPlayback = true;
        
        [self configureAudio];
        
        __weak __typeof(self) weakSelf = self;
        
        [self->_player addObserver:self forKeyPath:@"rate" options:0 context:nil];
        self->_playerObserversRegistered = true;
        
        if(self->_timeObserver != nil)
            [self->_player removeTimeObserver:self->_timeObserver];
        self->_timeObserver = [self->_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0) usingBlock:^(CMTime time) {
            __typeof(self) strongSelf = weakSelf;
            if (strongSelf && strongSelf->_eventEmitter != nil) {
                [strongSelf->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": strongSelf->_playerId,
                    @"eventType": @"ON_PROGRESS",
                    @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(time)],
                    @"duration": [NSNumber numberWithFloat:CMTimeGetSeconds(strongSelf->_player.currentItem.duration)],
                }];
            }
        }];

        if (self->_notficationCenterObserversRegistered) {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            self->_notficationCenterObserversRegistered = false;
        }
    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:[self->_player currentItem]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStalled:) name:AVPlayerItemPlaybackStalledNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFailToFinishPlaying:) name: AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        self->_notficationCenterObserversRegistered = true;
    }
    return self;
}

- (void)dispose {
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        
        if(self->_disposed)
            return;
        
        self->_disposed = true;
        
        if(self->_player != nil && self->_playerObserversRegistered) {
            [self->_player removeObserver:self forKeyPath:@"rate"];
            self->_playerObserversRegistered = false;
        }
        
        if (self->_notficationCenterObserversRegistered) {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            self->_notficationCenterObserversRegistered = false;
        }
        
        if(self->_timeObserver != nil) {
            [self->_player removeTimeObserver:self->_timeObserver];
            self->_timeObserver = nil;
        }
        
        if(self->_player.currentItem != nil && self->_currentItemObserversRegistered) {
            [self->_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"status"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            self->_currentItemObserversRegistered = false;
        }
        
        if(self->_player != nil) {
            [self->_player pause];
            [self->_player replaceCurrentItemWithPlayerItem:nil];
            self->_player = nil;
        }
        
        self->_paused = false;
        self->_loop = false;
        self->_source = nil;
    });
}

- (void)setSource:(NSDictionary *)source {
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        
        __weak __typeof(self) weakSelf = self;

        self->_source = source;
        
        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        
        if ([source[@"headers"] isKindOfClass:[NSDictionary class]]) {
            [headers addEntriesFromDictionary:source[@"headers"]];
        }
        
        NSString *urlString = source[@"url"];
        NSURL *url;
        AVURLAsset *asset;
        
        if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
            url = [NSURL URLWithString:urlString];
            asset = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey": headers}];
        } else {
            url = [NSURL fileURLWithPath:urlString];
            asset = [AVURLAsset URLAssetWithURL:url options:nil];
        }
        
        if(self->_player.currentItem != nil && self->_currentItemObserversRegistered) {
            [self->_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"status"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
            [self->_player.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            self->_currentItemObserversRegistered = false;
        }
        
        AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
        if (item) {
            [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [item addObserver:self forKeyPath:@"status" options:0 context:nil];
            [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:nil];
            [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:nil];
            [item addObserver:self forKeyPath:@"timedMetadata" options:NSKeyValueObservingOptionNew context:nil];
            self->_currentItemObserversRegistered = true;
        } else {
            [self->_player replaceCurrentItemWithPlayerItem:nil];
            return;
        }
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
        [audioSession setActive:YES error:nil];

        [self->_player replaceCurrentItemWithPlayerItem:item];
        
        id autoplay = [source objectForKey:@"autoplay"];
        if(autoplay && [autoplay boolValue]) {
            self->_paused = false;
            [self->_player play];
        }
        else {
            self->_paused = true;
            [self->_player pause];
        }
        
        id volume = [source objectForKey:@"volume"];
        if(volume && [volume isKindOfClass:[NSNumber class]]) {
            self->_volume = volume;
            [self->_player setVolume:[volume floatValue]];
        }
    });
}

- (void)play {
    _paused = false;
    if(_player == nil)
        return;
    [self configureAudio];
    [_player play];
}

- (void)pause {
    _paused = true;
    if(_player == nil)
        return;
    [_player pause];
}

- (void)setVolume:(NSNumber *)volume {
    _volume = volume;
    if(_player == nil)
        return;
    [_player setVolume:[volume floatValue]];
}

- (void)setLoop:(BOOL)loop {
    _loop = loop;
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
//          NSValue *toleranceValue = [NSValue valueWithCMTime:cmTolerance];
          
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
    if (object == self->_player || object == self->_player.currentItem) {
        if([keyPath isEqualToString:@"rate"]) {
            if (self->_player.rate == 1.0) {
                if(self->_eventEmitter != nil) {
                    [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": self->_playerId,
                        @"eventType": @"ON_PLAY"
                    }];
                }
            } else if (self->_player.rate == 0.0) {
                if(self->_eventEmitter != nil) {
                    [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": self->_playerId,
                        @"eventType": @"ON_PAUSE"
                    }];
                }
            }
        }
        else if([keyPath isEqualToString:@"status"]) {
            if (self->_player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                float duration = CMTimeGetSeconds(self->_player.currentItem.asset.duration);
                
                if (isnan(duration)) {
                    duration = 0.0;
                }
                
                if(self->_eventEmitter != nil) {
                    [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": self->_playerId,
                        @"eventType": @"ON_LOAD",
                        @"duration": [NSNumber numberWithFloat:duration],
                        @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(self->_player.currentItem.currentTime)],
                        @"canPlayReverse": [NSNumber numberWithBool:self->_player.currentItem.canPlayReverse],
                        @"canPlayFastForward": [NSNumber numberWithBool:self->_player.currentItem.canPlayFastForward],
                        @"canPlaySlowForward": [NSNumber numberWithBool:self->_player.currentItem.canPlaySlowForward],
                        @"canPlaySlowReverse": [NSNumber numberWithBool:self->_player.currentItem.canPlaySlowReverse],
                        @"canStepBackward": [NSNumber numberWithBool:self->_player.currentItem.canStepBackward],
                        @"canStepForward": [NSNumber numberWithBool:self->_player.currentItem.canStepForward]
                    }];
                }
            } else if (self->_player.currentItem.status == AVPlayerItemStatusFailed) {
                if(self->_eventEmitter != nil) {
                    [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                        @"playerId": self->_playerId,
                        @"eventType": @"ON_ERROR",
                        @"errorCode": [NSNumber numberWithInteger: self->_player.currentItem.error.code],
                        @"errorMessage": [self->_player.currentItem.error localizedDescription] == nil ? @"" : [self->_player.currentItem.error localizedDescription]
                    }];
                }
            }
        }
        else if([keyPath isEqualToString:@"timedMetadata"]) {
            if(self->_eventEmitter != nil) {
                [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": self->_playerId,
                    @"eventType": @"ON_TIMED_METADATA"
                }];
            }
        }
        else if([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            if(self->_eventEmitter != nil) {
                [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": self->_playerId,
                    @"eventType": @"ON_BUFFERING"
                }];
            }
        }
        else if([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            if(self->_eventEmitter != nil) {
                [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": self->_playerId,
                    @"eventType": @"ON_BUFFERING"
                }];
            }
        }
        else if([keyPath isEqualToString:@"loadedTimeRanges"]) {
            NSArray *timeRanges = [self->_player.currentItem.loadedTimeRanges valueForKey:@"CMTimeRangeValue"];
            CMTimeRange timeRange = [timeRanges.firstObject CMTimeRangeValue];
            float bufferingProgress = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
            if(self->_eventEmitter != nil) {
                [self->_eventEmitter sendEventWithName:@"playerEvent" body:@{
                    @"playerId": self->_playerId,
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
    
    if (_loop) {
        AVPlayerItem *item = [notification object];
        [item seekToTime:kCMTimeZero completionHandler:nil];
    }
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

- (void)configureAudio
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionCategory category = AVAudioSessionCategoryPlayback;
    AVAudioSessionCategoryOptions options = 0;

    if(@available(iOS 13.0, *)) {
        [session setCategory:category mode:AVAudioSessionModeDefault routeSharingPolicy:AVAudioSessionRouteSharingPolicyLongFormAudio options:options error:nil];
    } else if(@available(iOS 11.0, *)) {
        [session setCategory:category mode:AVAudioSessionModeDefault routeSharingPolicy:AVAudioSessionRouteSharingPolicyLongForm options:options error:nil];
    } else {
        [session setCategory:category withOptions:options error:nil];
    }
    [session setCategory:category error:nil];
}

@end
