import AVKit

class Player: NSObject, PlayerObserverHandler {
    internal var player: AVPlayer?
    private var playerId: String?
    private var eventEmitter: RCTEventEmitter?
    private var volume: NSNumber?
    private var paused: Bool = false
    private var disposed: Bool = false
    private var loop: Bool? = false
    private var playerObserver: PlayerObserver = PlayerObserver()
    
    init(eventEmitter: RCTEventEmitter, playerId: String) {
        self.eventEmitter = eventEmitter
        self.playerId = playerId
        self.player = AVPlayer()
        super.init()

        self.disposed = false

        self.player?.allowsExternalPlayback = true
        self.player?.actionAtItemEnd = .none

        self.configureAudio()
        
        playerObserver._handlers = self
    }
    
    deinit { dispose() }
    
    func dispose() {
        DispatchQueue.global(qos: .default).async {
            
            guard !self.disposed else { return }
            
            self.disposed = true
            
            if let player = self.player {
                player.pause()
                player.replaceCurrentItem(with: nil)
                self.player = nil
            }
            
            NotificationCenter.default.removeObserver(self)
            self.playerObserver.clearPlayer()
            
            self.paused = false
            self.loop = false
        }
    }
    
    func setSource(_ source: NSDictionary) {
        DispatchQueue.global(qos: .default).async { [weak self] in
            
            self?.playerObserver.player = nil
            self?.playerObserver.playerItem = nil
            
            guard let self = self else { return }
            
            var headers = [String: String]()
            
            if let sourceHeaders = source["headers"] as? [String: String] {
                headers.merge(sourceHeaders) { (_, new) in new }
            }
            
            if let urlString = source["url"] as? String {
                let url: URL
                let asset: AVURLAsset
                
                if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
                    url = URL(string: urlString)!
                    asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                } else {
                    url = URL(fileURLWithPath: urlString)
                    asset = AVURLAsset(url: url)
                }
                
                let item = AVPlayerItem(asset: asset)

                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setCategory(.playback)
                try? audioSession.setActive(true)
                
                playerObserver.playerItem = item
                
                self.player?.replaceCurrentItem(with: item)
                
                playerObserver.player = self.player
                
                if let autoplay = source["autoplay"] as? Bool, autoplay {
                    self.paused = false
                    self.player?.play()
                } else {
                    self.paused = true
                    self.player?.pause()
                }

                if let volume = source["volume"] as? NSNumber {
                    self.volume = volume
                    self.player?.volume = volume.floatValue
                }
            }
        }
    }

    func play() {
        paused = false
        guard let player = player else { return }
        configureAudio()
        player.play()
    }

    func pause() {
        paused = true
        guard let player = player else { return }
        player.pause()
    }

    func setVolume(_ volume: NSNumber) {
        self.volume = volume
        guard let player = player else { return }
        player.volume = volume.floatValue
    }

    func setLoop(_ loop: Bool) {
        self.loop = loop
    }

    func seek(_ seek: NSDictionary) {
        guard let player = player,
              let time = seek["time"] as? NSNumber,
              let tolerance = seek["tolerance"] as? NSNumber else {
            return
        }
        
        let timeScale = CMTimeScale(1000)
        
        if let item = player.currentItem, item.status == .readyToPlay {
            let cmSeekTime = CMTimeMakeWithSeconds(time.doubleValue, preferredTimescale: timeScale)
            let current = item.currentTime()
            let cmTolerance = CMTimeMakeWithSeconds(tolerance.doubleValue, preferredTimescale: timeScale)
            
            if CMTimeCompare(current, cmSeekTime) != 0 {
                player.seek(to: cmSeekTime, toleranceBefore: cmTolerance, toleranceAfter: cmTolerance) { [weak self] finished in
                    guard let self = self else { return }
                    let currentTime = CMTimeGetSeconds(item.currentTime())
                    let seekTimeValue = NSValue(time: cmSeekTime)
                    self.sendPlayerEvent("ON_SEEK", [
                        "currentTime": NSNumber(value: currentTime),
                        "seekTime": seekTimeValue
                    ])
                }
            }
        }
    }
    
    func handleTimeUpdate(time: CMTime) {
        sendPlayerEvent("ON_PROGRESS", [
            "currentTime": CMTimeGetSeconds(time),
            "duration": CMTimeGetSeconds(player?.currentItem?.duration ?? CMTime.zero)
        ])
    }

    func handlePlaybackRateChange(player: AVPlayer, change: NSKeyValueObservedChange<Float>) {
        if player.rate == 1.0 {
            sendPlayerEvent("ON_PLAY")
        } else if player.rate == 0.0 {
            sendPlayerEvent("ON_PAUSE")
        }
    }

    func handlePlayerItemStatusChange(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<AVPlayerItem.Status>) {
        switch playerItem.status {
        case .readyToPlay:
            handleReadyToPlay(playerItem: playerItem)
        case .failed:
            handleFailedToPlay(playerItem: playerItem)
        default:
            break
        }
    }

    func handleReadyToPlay(playerItem: AVPlayerItem) {
        let duration = CMTimeGetSeconds(playerItem.asset.duration)
        let currentTime = CMTimeGetSeconds(playerItem.currentTime())
        
        playerObserver.attachPlayerEventListeners()

        sendPlayerEvent("ON_LOAD", [
            "duration": NSNumber(value: duration),
            "currentTime": NSNumber(value: currentTime),
            "canPlayReverse": NSNumber(value: playerItem.canPlayReverse),
            "canPlayFastForward": NSNumber(value: playerItem.canPlayFastForward),
            "canPlaySlowForward": NSNumber(value: playerItem.canPlaySlowForward),
            "canPlaySlowReverse": NSNumber(value: playerItem.canPlaySlowReverse),
            "canStepBackward": NSNumber(value: playerItem.canStepBackward),
            "canStepForward": NSNumber(value: playerItem.canStepForward)
        ])
    }

    func handleFailedToPlay(playerItem: AVPlayerItem) {
        let error = playerItem.error! as NSError
        sendPlayerEvent("ON_ERROR", [
            "errorCode": NSNumber(value: error.code),
            "errorMessage": error.localizedDescription 
        ])
    }

    func handleTimeMetadataChange(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<[AVMetadataItem]?>) {
        sendPlayerEvent("ON_TIMED_METADATA")
    }
    
    func handlePlaybackBufferKeyEmpty(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        sendPlayerEvent("ON_BUFFERING")
    }
    
    func handlePlaybackLikelyToKeepUp(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) {
        sendPlayerEvent("ON_BUFFERING")
    }

    func handleLoadedTimeRanges(playerItem: AVPlayerItem, change: NSKeyValueObservedChange<[NSValue]>) {
        let timeRanges = playerItem.loadedTimeRanges
        guard let timeRange = timeRanges.first?.timeRangeValue else { return }

        let bufferingProgress = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
        sendPlayerEvent("ON_BUFFERING", ["progress": NSNumber(value: bufferingProgress)])
    }
    
    func handlePlayerItemDidReachEnd(notification: NSNotification!) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError {
            sendPlayerEvent("ON_ERROR", [
                "errorCode": NSNumber(value: error.code),
                "errorMessage": error.localizedDescription
            ])
        }
    }

    func handlePlaybackStalled(notification: NSNotification!) {
        sendPlayerEvent("ON_STALLED")
    }

    func playerItemDidReachEnd(_ notification: Notification) {
        sendPlayerEvent("ON_END")

        guard let loop = loop, loop else {
            playerObserver.removePlayerTimeObserver()
            return
        }

        if let item = notification.object as? AVPlayerItem {
            item.seek(to: CMTime.zero, completionHandler: nil)
            player?.play()
        }
    }

    func handleAudioRouteChange(notification: NSNotification!) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }

        switch AVAudioSession.RouteChangeReason(rawValue: reason) {
        case .oldDeviceUnavailable?, .override?:
            sendPlayerEvent("ON_BECOME_NOISY")
        default:
            break
        }
    }

    func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        let category = AVAudioSession.Category.playback
        let options: AVAudioSession.CategoryOptions = []

        if #available(iOS 13.0, *) {
            try? session.setCategory(category, mode: .default, policy: .longFormAudio, options: options)
        } else if #available(iOS 11.0, *) {
            try? session.setCategory(category, mode: .default, policy: .longForm, options: options)
        } else {
            try? session.setCategory(category, options: options)
        }
        try? session.setActive(true)
    }

    func sendPlayerEvent(_ eventType: String, _ eventData: [String: Any]? = nil) {
        guard let eventEmitter = eventEmitter else { return }

        var eventBody: [String: Any] = [
            "playerId": playerId as Any,
            "eventType": eventType
        ]

        if let eventData = eventData {
            eventBody.merge(eventData) { (_, new) in new }
        }

        eventEmitter.sendEvent(withName: "playerEvent", body: eventBody)
    }
}
