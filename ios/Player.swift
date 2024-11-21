import MobileVLCKit
import Promises

class Player: NSObject, VLCMediaPlayerDelegate, VLCMediaListPlayerDelegate {
    internal var player: VLCMediaPlayer?
    private var playerId: String?
    private var eventEmitter: RCTEventEmitter?
    private var volume: NSNumber?
    private var paused: Bool = false
    private var disposed: Bool = false
    private var loop: Bool = false
    private var loaded: Bool = false
    
    private var volumeFadeTimer: Timer?
    private var volumeFadeStart: Double?
    private var volumeFadeDuration: Float = 3
    private var volumeFadeTarget: Float = 1
    private var volumeFadeInitialVolume: Float = 0

    init(eventEmitter: RCTEventEmitter, playerId: String) {
        super.init()
        self.eventEmitter = eventEmitter
        self.playerId = playerId
        self.player = VLCMediaPlayer()
        self.disposed = false
        self.player?.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mediaPlayerStateChanged(_:)),
                                               name: NSNotification.Name("VLCMediaPlayerStateChanged"),
                                               object: nil)
        self.player?.libraryInstance.debugLogging = true
        self.player?.libraryInstance.debugLoggingLevel = 3
    }
    
    deinit {
        dispose()
    }
    
    func dispose() {
        guard !self.disposed else { return }
        
        self.loaded = false
        self.disposed = true
        
        self.stopVolumeFade(false)
        
        self.player?.stop()
        self.player = nil
        
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("VLCMediaPlayerStateChanged"), object: nil)
        
        self.paused = false
        self.loop = false
    }
    
    func delay(seconds: Int = 0) -> Promise<Void> {
        return Promise<Void>(on: .global()) { fulfill, reject in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(seconds)) {
                fulfill(())
            }
        }
    }
    
    func setSource(_ source: NSDictionary) {
        let dispatchClosure = {
            do {
                self.delay()
                    .then { [weak self] in
                        guard let self = self else { return }
                        
                        self.loaded = false
                        self.stopVolumeFade(false)
                        
                        if let urlString = source["url"] as? String {
                            let media: VLCMedia
                            
                            print(urlString)
                            
                            if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
                                guard let url = URL(string: urlString) else { return }
                                media = VLCMedia(url: url)
                                media.addOption("-vv")
                                media.addOptions([
                                    "network-caching": 100
                                ])
                                // media.addOption("--network-caching=100")
                                // media.addOption("--file-caching=1000")
                                // media.addOption("--http-chunk")
                            } else {
                                let url = URL(fileURLWithPath: urlString)
                                media = VLCMedia(url: url)
                            }
                            
                            self.player?.media = media
                            
                            /*if let autoplay = source["autoplay"] as? Bool, autoplay {
                                self.paused = false
                                self.player?.play()
                            } else {
                                self.paused = true
                                self.player?.pause()
                            }*/
                            
                            if let volume = source["volume"] as? NSNumber {
                                self.volume = volume
                                self.player?.audio?.volume = Int32(volume.floatValue * 100)
                            }
                        }
                    }.catch { _ in }
            }
        }
        DispatchQueue.global(qos: .default).async(execute: dispatchClosure)
    }

    func play() {
        print("play command")
        paused = false
        player?.play()
    }

    func pause() {
        print("pause command")
        paused = true
        player?.pause()
    }

    func setVolume(_ volume: NSNumber) {
        stopVolumeFade(false)
        self.volume = volume
        player?.audio?.volume = Int32(volume.floatValue * 100)
    }

    func setLoop(_ loop: Bool) {
        self.loop = loop
    }
    
    func seek(_ position: NSDictionary) {
        guard let player = player else { return }
        guard let media = player.media else { return }
        
        let duration = Int32(media.length.intValue) // duration3 in milliseconds
        let targetTime = Int32(((position["time"] as? NSNumber)?.floatValue ?? 0) * 1000.0)
        
        if targetTime >= 0 && targetTime <= duration {
            stopVolumeFade(true)
            player.time = VLCTime(int: targetTime)
        }
        
        sendPlayerEvent("ON_SEEK", ["position": position])
    }

    func fadeVolume(_ target: NSNumber, _ duration: NSNumber, _ fromVolume: NSNumber) {
        if duration.floatValue <= 0 || player == nil { return }
        
        if volumeFadeTimer != nil { stopVolumeFade(true) }
        
        volumeFadeStart = Date().timeIntervalSince1970
        volumeFadeTarget = target.floatValue
        volumeFadeDuration = duration.floatValue
        volumeFadeInitialVolume = fromVolume.floatValue
        self.player?.audio?.volume = Int32(fromVolume.floatValue * 100)
        
        DispatchQueue.main.async {
            self.volumeFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                guard let fadeStart = self.volumeFadeStart, let audio = self.player?.audio else { return }
                
                let timePassed = Float(Date().timeIntervalSince1970 - fadeStart) / self.volumeFadeDuration
                
                let newVolume: Float
                if timePassed >= 1.0 {
                    newVolume = self.volumeFadeTarget
                    self.stopVolumeFade(true)
                } else {
                    newVolume = self.volumeFadeInitialVolume + (self.volumeFadeTarget - self.volumeFadeInitialVolume) * timePassed
                }
                audio.volume = Int32(newVolume * 100)
            }
        }
    }
    
    func stopVolumeFade(_ changeVolume: Bool) {
        volumeFadeStart = nil
        volumeFadeTimer?.invalidate()
        volumeFadeTimer = nil
        if let volume = self.volume, changeVolume {
            player?.audio?.volume = Int32(volume.floatValue * 100)
        }
    }

    func sendPlayerEvent(_ eventType: String, _ eventData: [String: Any]? = nil) {
        guard let eventEmitter = eventEmitter else { return }

        var eventBody: [String: Any] = [
            "playerId": playerId as Any,
            "eventType": eventType
        ]

        if let eventData = eventData {
            eventBody.merge(eventData) { _, new in new }
        }

        eventEmitter.sendEvent(withName: "playerEvent", body: eventBody)
    }
    
    @objc func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = player else { return }

        switch player.state {
        case .opening:
            sendPlayerEvent("ON_OPENING")
            print("opening")
        case .buffering:
            sendPlayerEvent("ON_BUFFERING")
            print("buffering")
            if (!self.loaded) {
                print("loaded")
                self.loaded = true
                
                let duration = NSNumber(value: Double(player.media?.length.intValue ?? 0) / 1000.0)
                let currentTime = NSNumber(value: 0)
                let canPlayReverse = NSNumber(value: true)
                let canPlayFastForward = NSNumber(value: true)
                let canPlaySlowForward = NSNumber(value: true)
                let canPlaySlowReverse = NSNumber(value: true)
                let canStepBackward = NSNumber(value: true)
                let externalPlayback = NSNumber(value: false)
                let videoWidth = NSNumber(value: 0)
                let videoHeight = NSNumber(value: 0)

                let eventParams: [String: Any] = [
                    "duration": duration,
                    "currentTime": currentTime,
                    "canPlayReverse": canPlayReverse,
                    "canPlayFastForward": canPlayFastForward,
                    "canPlaySlowForward": canPlaySlowForward,
                    "canPlaySlowReverse": canPlaySlowReverse,
                    "canStepBackward": canStepBackward,
                    "externalPlayback": externalPlayback,
                    "videoWidth": videoWidth,
                    "videoHeight": videoHeight
                ]

                sendPlayerEvent("ON_LOAD", eventParams)
            }
        case .playing:
            sendPlayerEvent("ON_PLAYING")
            print("playing")
        case .paused:
            sendPlayerEvent("ON_PAUSED")
            print("paused")
        case .stopped:
            sendPlayerEvent("ON_STOPPED")
            print("stopped")
        case .ended:
            sendPlayerEvent("ON_ENDED")
            print("ended")
        case .esAdded:
            sendPlayerEvent("ON_ADDED")
            print("added")
        case .error:
            sendPlayerEvent("ON_ERROR")
            print("error")
        @unknown default:
            sendPlayerEvent("ON_ERROR")
            print("unknown")
        }
    }

   func mediaPlayerTimeChanged(_ aNotification: Notification) {
       guard let player = player else { return }
       
       let currentTime = Double(player.time.intValue) / 1000.0
       let duration = Double(player.media?.length.intValue ?? 0) / 1000.0
       
       sendPlayerEvent("ON_PROGRESS", [
           "currentTime": NSNumber(value: currentTime),
           "duration": NSNumber(value: duration)
       ])
   }
}
