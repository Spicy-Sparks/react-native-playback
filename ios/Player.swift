import AVKit
import Promises

class Player: NSObject, PlayerObserverHandler {
    internal var player: AVPlayer?
    private var playerId: String?
    private var eventEmitter: RCTEventEmitter?
    private var volume: NSNumber?
    private var paused: Bool = false
    private var disposed: Bool = false
    private var loop: Bool? = false
    private var playerObserver: PlayerObserver = PlayerObserver()
    
    private var volumeFadeTimer: Timer?
    private var volumeFadeStart: Double?
    private var volumeFadeDuration: Float = 3
    private var volumeFadeTarget: Float = 1
    private var volumeFadeInitialVolume: Float = 0
    
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
    
    deinit {
        dispose()
    }
    
    func dispose() {
        let dispatchClosure = {
            do {
                self.delay()
                    .then{ [weak self] in
                        guard let self = self else { return }
                
                        guard self.disposed else { return }
                        
                        self.disposed = true
                        
                        self.stopVolumeFade(false)
                        
                        if let player = self.player {
                            player.pause()
                            player.replaceCurrentItem(with: nil)
                            self.player = nil
                        }
                        
                        NotificationCenter.default.removeObserver(self)
                        self.playerObserver.clearPlayer()
                        
                        self.paused = false
                        self.loop = false
                    }.catch{ _ in }
            }
        }
        DispatchQueue.global(qos: .default).async(execute: dispatchClosure)
    }
    
    func delay(seconds: Int = 0) -> Promise<Void> {
        return Promise<Void>(on: .global()) { fulfill, reject in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(seconds)) / Double(NSEC_PER_SEC), execute: {
                fulfill(())
            })
        }
    }
    
    func setSource(_ source: NSDictionary) {
        let dispatchClosure = {
            do {
                self.delay()
                    .then{ [weak self] in
                        guard let self = self else { return }
                        
                        self.stopVolumeFade(false)
                        
                        self.playerObserver.player = nil
                        self.playerObserver.playerItem = nil
                        
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
                            
                            self.playerObserver.playerItem = item
                            
                            self.player?.replaceCurrentItem(with: item)
                            
                            self.playerObserver.player = self.player

                            self.player?.actionAtItemEnd = .none
                            
                            self.player?.allowsExternalPlayback = true
                            
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
                    }.catch{ _ in }
            }
        }
        DispatchQueue.global(qos: .default).async(execute: dispatchClosure)
    }

    func play() {
        paused = false
        if (player == nil) { return }
        configureAudio()
        player?.play()
    }

    func pause() {
        paused = true
        if (player == nil) { return }
        player?.pause()
    }

    func setVolume(_ volume: NSNumber) {
        stopVolumeFade(false)
        self.volume = volume
        if (player == nil) { return }
        player?.volume = volume.floatValue
    }

    func setLoop(_ loop: Bool) {
        self.loop = loop
    }

    func seek(_ seek: NSDictionary) -> Bool {
        if (player == nil || player?.currentItem == nil) { return false }
        
        guard let time = seek["time"] as? NSNumber,
              let tolerance = seek["tolerance"] as? NSNumber else {
            return false
        }
            
        let timeScale = CMTimeScale(1000)
        
        if let item = player?.currentItem, item.status == .readyToPlay {
            let cmSeekTime = CMTimeMakeWithSeconds(time.doubleValue, preferredTimescale: timeScale)
            let current = item.currentTime()
            let cmTolerance = CMTimeMakeWithSeconds(tolerance.doubleValue, preferredTimescale: timeScale)
            
            if CMTimeCompare(current, cmSeekTime) != 0 {
                stopVolumeFade(true)
                player?.seek(to: cmSeekTime, toleranceBefore: cmTolerance, toleranceAfter: cmTolerance) { [weak self] finished in
                    guard let self = self else { return }
                    let currentTime = CMTimeGetSeconds(item.currentTime())
                    let seekTimeValue = NSValue(time: cmSeekTime)
                    self.sendPlayerEvent("ON_SEEK", [
                        "currentTime": NSNumber(value: currentTime),
                        "seekTime": seekTimeValue
                    ])
                }
                return true
            }
        }
        return false
    }
    
    func fadeVolume(_ target: NSNumber, _ duration: NSNumber) {
        if (duration.floatValue <= 0 || self.player == nil) { return }
        
        if (volumeFadeTimer != nil) { stopVolumeFade(true) }
        
        volumeFadeStart = Date().timeIntervalSince1970
        volumeFadeTarget = target.floatValue
        volumeFadeDuration = duration.floatValue
        volumeFadeInitialVolume = self.player!.volume
        
        DispatchQueue.main.async {
            self.volumeFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer) in
                if (self.player == nil || self.volumeFadeStart == nil) { return }
                
                let timePassed = (Date().timeIntervalSince1970 - self.volumeFadeStart!) / Double(self.volumeFadeDuration)
            
                if self.player!.volume < self.volumeFadeTarget {
                    let volumeIncrement = pow(Float(timePassed), 2) * self.volumeFadeTarget
                    let newVolume = min(volumeIncrement, self.volumeFadeTarget)
                    self.player!.volume = newVolume
                } else if self.player!.volume > self.volumeFadeTarget {
                    let volumeIncrement = -pow(Float(timePassed), 2) + self.volumeFadeInitialVolume
                    let newVolume = max(volumeIncrement, self.volumeFadeTarget)
                    self.player!.volume = newVolume
                } else {
                    self.volume = NSNumber(value: self.volumeFadeTarget)
                    self.stopVolumeFade(true)
                }
            }
        }
    }
    
    func stopVolumeFade (_ changeVolume: Bool) {
        volumeFadeStart = nil
        volumeFadeTimer?.invalidate()
        volumeFadeTimer = nil
        volumeFadeInitialVolume = 0
        if (volume != nil && changeVolume) {
            player?.volume = volume!.floatValue
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
    
    func handleExternalPlaybackActiveChange(player: AVPlayer, change: NSKeyValueObservedChange<Bool>) {
        sendPlayerEvent("ON_EXTERNAL_PLAYER", [
            "connected": player.isExternalPlaybackActive 
        ])
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
        let videoWidth = playerItem.tracks.first?.assetTrack?.naturalSize.width ?? 0
        let videoHeight = playerItem.tracks.first?.assetTrack?.naturalSize.height ?? 0
        
        let dispatchClosure = {
            self.playerObserver.attachPlayerEventListeners()
        }
        DispatchQueue.global(qos: .default).async(execute: dispatchClosure)
        
        sendPlayerEvent("ON_LOAD", [
            "duration": NSNumber(value: duration),
            "currentTime": NSNumber(value: currentTime),
            "canPlayReverse": NSNumber(value: playerItem.canPlayReverse),
            "canPlayFastForward": NSNumber(value: playerItem.canPlayFastForward),
            "canPlaySlowForward": NSNumber(value: playerItem.canPlaySlowForward),
            "canPlaySlowReverse": NSNumber(value: playerItem.canPlaySlowReverse),
            "canStepBackward": NSNumber(value: playerItem.canStepBackward),
            "externalPlayback": player?.isExternalPlaybackActive ?? false,
            "videoWidth": NSNumber(value: videoWidth),
            "videoHeight": NSNumber(value: videoHeight)
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
