import AVFoundation
import AVKit
import Foundation

@objc
protocol PlayerObserverHandlerObjc {
    func handlePlaybackStalled(notification:NSNotification!)
    func handlePlayerItemDidReachEnd(notification:NSNotification!)
    func handleAudioRouteChange(notification:NSNotification!)
}

protocol PlayerObserverHandler: PlayerObserverHandlerObjc {
    func handleTimeUpdate(time:CMTime)
    func handleTimeMetadataChange(playerItem:AVPlayerItem, change:NSKeyValueObservedChange<[AVMetadataItem]?>)
    func handlePlayerItemStatusChange(playerItem:AVPlayerItem, change:NSKeyValueObservedChange<AVPlayerItem.Status>)
    func handleLoadedTimeRanges(playerItem:AVPlayerItem, change:NSKeyValueObservedChange<[NSValue]>)
    func handlePlaybackBufferKeyEmpty(playerItem:AVPlayerItem, change:NSKeyValueObservedChange<Bool>)
    func handlePlaybackLikelyToKeepUp(playerItem:AVPlayerItem, change:NSKeyValueObservedChange<Bool>)
    func handlePlaybackRateChange(player: AVPlayer, change: NSKeyValueObservedChange<Float>)
    func handleExternalPlaybackActiveChange(player: AVPlayer, change: NSKeyValueObservedChange<Bool>)
}

class PlayerObserver: NSObject {
    weak var _handlers: PlayerObserverHandler?
    
    var player:AVPlayer? {
        willSet {
            removePlayerObservers()
            removePlayerTimeObserver()
        }
        didSet {
            if player != nil {
                addPlayerObservers()
                addPlayerTimeObserver()
            }
        }
    }
    var playerItem:AVPlayerItem? {
        willSet {
            removePlayerItemObservers()
        }
        didSet {
            if playerItem != nil {
                addPlayerItemObservers()
            }
        }
    }
    
    private var _progressUpdateInterval:TimeInterval = 250
    private var _timeObserver:Any?
    
    private var _playerRateChangeObserver:NSKeyValueObservation?
    private var _playerExternalPlaybackActiveChangeObserver:NSKeyValueObservation?
    private var _playerItemStatusObserver:NSKeyValueObservation?
    private var _playerLoadedTimeRangesObserver:NSKeyValueObservation?
    private var _playerPlaybackBufferEmptyObserver:NSKeyValueObservation?
    private var _playerPlaybackLikelyToKeepUpObserver:NSKeyValueObservation?
    private var _playerTimedMetadataObserver:NSKeyValueObservation?
    private var _playerExternalPlaybackObserver:NSKeyValueObservation?
    
    deinit {
        if let _handlers = _handlers {
            NotificationCenter.default.removeObserver(_handlers)
        }
    }
    
    func addPlayerObservers() {
        guard let player = player, let _handlers = _handlers else { return }
        _playerRateChangeObserver = player.observe(\.rate, options: [.old], changeHandler: _handlers.handlePlaybackRateChange)
        _playerExternalPlaybackActiveChangeObserver = player.observe(\.isExternalPlaybackActive, options: [.old], changeHandler: _handlers.handleExternalPlaybackActiveChange)
    }
    
    func removePlayerObservers() {
        _playerRateChangeObserver?.invalidate()
        _playerExternalPlaybackActiveChangeObserver?.invalidate()
    }
    
    func addPlayerItemObservers() {
        guard let playerItem = playerItem, let _handlers = _handlers else { return }
        _playerItemStatusObserver = playerItem.observe(\.status, options:  [.new, .old], changeHandler: _handlers.handlePlayerItemStatusChange)
        _playerLoadedTimeRangesObserver = playerItem.observe(\.loadedTimeRanges, options:  [.new, .old], changeHandler: _handlers.handleLoadedTimeRanges)
        _playerPlaybackBufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty, options:  [.new, .old], changeHandler: _handlers.handlePlaybackBufferKeyEmpty)
        _playerPlaybackLikelyToKeepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp, options:  [.new, .old], changeHandler: _handlers.handlePlaybackLikelyToKeepUp)
        _playerTimedMetadataObserver = playerItem.observe(\.timedMetadata, options:  [.new], changeHandler: _handlers.handleTimeMetadataChange)
    }
    
    func removePlayerItemObservers() {
        _playerItemStatusObserver?.invalidate()
        _playerLoadedTimeRangesObserver?.invalidate()
        _playerPlaybackBufferEmptyObserver?.invalidate()
        _playerPlaybackLikelyToKeepUpObserver?.invalidate()
        _playerTimedMetadataObserver?.invalidate()
    }
    
    func addPlayerTimeObserver() {
        guard let _handlers = _handlers else { return }
        removePlayerTimeObserver()
        let progressUpdateIntervalMS:Float64 = _progressUpdateInterval / 1000
        _timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTimeMakeWithSeconds(progressUpdateIntervalMS, preferredTimescale: Int32(NSEC_PER_SEC)),
            queue:nil,
            using:_handlers.handleTimeUpdate
        )
    }
    
    func removePlayerTimeObserver() {
        if _timeObserver != nil {
            player?.removeTimeObserver(_timeObserver as Any)
            _timeObserver = nil
        }
    }
    
    func attachPlayerEventListeners() {
        guard let _handlers = _handlers else { return }
        NotificationCenter.default.removeObserver(_handlers,
                                                  name:NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object:player?.currentItem)
        
        NotificationCenter.default.addObserver(_handlers,
                                               selector:#selector(PlayerObserverHandler.handlePlayerItemDidReachEnd(notification:)),
                                               name:NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object:player?.currentItem)
        
        NotificationCenter.default.removeObserver(_handlers,
                                                  name:NSNotification.Name.AVPlayerItemPlaybackStalled,
                                                  object:nil)
        
        NotificationCenter.default.addObserver(_handlers,
                                               selector:#selector(PlayerObserverHandler.handlePlaybackStalled(notification:)),
                                               name:NSNotification.Name.AVPlayerItemPlaybackStalled,
                                               object:nil)
        
        NotificationCenter.default.removeObserver(_handlers,
                                                  name:AVAudioSession.routeChangeNotification,
                                                  object:nil)
        
        NotificationCenter.default.addObserver(_handlers,
                                               selector:#selector(PlayerObserverHandler.handleAudioRouteChange(notification:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object:nil)
    }
    
    func clearPlayer() {
        player = nil
        playerItem = nil
        if let _handlers = _handlers {
            NotificationCenter.default.removeObserver(_handlers)
        }
    }
}
