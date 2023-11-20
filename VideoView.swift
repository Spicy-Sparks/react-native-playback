import AVKit

class VideoView: UIView {
    private var playerId: String?
    private var player: AVPlayer?
    private var playerViewController = VideoViewController()
    private var playerLayer: AVPlayerLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        playerViewController = VideoViewController()
        playerViewController.updatesNowPlayingInfoCenter = false
        playerViewController.allowsPictureInPicturePlayback = false
        playerViewController.view.frame = bounds
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func setPlayerId(_ playerId: String) {
        self.playerId = playerId
        player = Playback.players[playerId]?.player
        
        guard let player = player else {
            return
        }
        
        playerViewController.player = player
        
//        var viewController: UIViewController?
//        var nextResponder: UIResponder? = self
//        
//        while nextResponder != nil {
//            nextResponder = nextResponder?.next
//            if let responder = nextResponder as? UIViewController {
//                viewController = responder
//                break
//            }
//        }
        
        guard let keyWindow = UIApplication.shared.keyWindow,
              let rootViewController = keyWindow.rootViewController else {
            return
        }
        
        var viewController: UIViewController? = rootViewController
        
        while let presentedViewController = viewController?.presentedViewController {
            viewController = presentedViewController
        }
        
        
        
        if let viewController = viewController {
            viewController.addChild(playerViewController)
            addSubview(playerViewController.view)
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = frame
        layer.addSublayer(playerLayer!)
        
        print("Received playerId: \(playerId)")
    }
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        guard let _ = player, let playerLayer = playerLayer else {
            return
        }
        
        playerLayer.player = nil
        playerViewController.player = nil
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        guard let player = player, let playerLayer = playerLayer else {
            return
        }
        
        playerLayer.player = player
        
    }
}
