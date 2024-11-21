import UIKit
import MobileVLCKit

class VideoView: UIView {
    private var playerId: String?
    private var player: VLCMediaPlayer?
    private var resizeMode: String?

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

    private func removePlayerView() {
        subviews.forEach { $0.removeFromSuperview() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        removePlayerView()
    }

    @objc
    func setPlayerId(_ playerId: String) {
        DispatchQueue.main.async {
            self.playerId = playerId
            self.removePlayerView()

            guard let vlcPlayer = Playback.players[playerId]?.player as? VLCMediaPlayer else { return }
            self.player = vlcPlayer

            let videoView = UIView(frame: self.bounds)
            videoView.translatesAutoresizingMaskIntoConstraints = true
            self.addSubview(videoView)
            
            vlcPlayer.drawable = videoView
            self.applyResizeMode()
        }
    }

    @objc
    func setResizeMode(_ resizeMode: String) {
        DispatchQueue.main.async {
            self.resizeMode = resizeMode
            self.applyResizeMode()
        }
    }

    private func applyResizeMode() {
        guard let vlcPlayer = player else { return }

        switch resizeMode {
        case "contain", "none":
            vlcPlayer.scaleFactor = 0 // Maintains aspect ratio with black bars
        case "cover":
            vlcPlayer.scaleFactor = 1 // Crops to fill the view
        case "stretch":
            vlcPlayer.scaleFactor = -1 // Stretches the video
        default:
            vlcPlayer.scaleFactor = 0
        }
    }

    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        player?.pause()
    }

    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        player?.play()
    }
}
