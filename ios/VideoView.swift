import AVKit
import Promises

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
        if #available(iOS 16.0, *) {
            playerViewController.allowsVideoFrameAnalysis = false
        }
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
        self.player = Playback.players[playerId]?.player
        
        guard let player = self.player else {
            return
        }
        
        self.playerViewController.player = player
        
        var viewController = self.reactViewController()
    
        if (viewController == nil) {
            guard let keyWindow = UIApplication.shared.keyWindow,
                  let rootViewController = keyWindow.rootViewController else {
                return
            }

            while let presentedViewController = rootViewController.presentedViewController {
                viewController = presentedViewController
            }
        }
        
        if let viewController = viewController {
            viewController.addChild(self.playerViewController)
            self.addSubview(self.playerViewController.view)
        }
        
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer?.frame = self.frame
        
        self.layer.addSublayer(self.playerLayer!)
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
