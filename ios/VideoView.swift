import AVKit

class VideoView: UIView {
    private var player: AVPlayer?
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
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func removePlayerLayer() {
        layer.sublayers?.reversed().forEach { $0.removeFromSuperlayer() }
        playerLayer = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removePlayerLayer()
    }
    
    @objc
    func setPlayerId(_ playerId: String) {
        DispatchQueue.main.async {
            self.removePlayerLayer()
            
            self.player = Playback.players[playerId]?.player
            if (self.player == nil) { return }
            
            self.playerLayer = AVPlayerLayer(player: self.player)
            if (self.playerLayer == nil) { return }
            
            self.playerLayer?.frame = self.frame
            self.layer.addSublayer(self.playerLayer!)
        }
    }
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        if (player == nil || playerLayer == nil) { return }
        playerLayer?.player = nil
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        if (player == nil || playerLayer == nil) { return }
        playerLayer?.player = player
    }
}
