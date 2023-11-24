@objc(VideoViewManager)
class VideoViewManager: RCTViewManager {

    override func view() -> (VideoView) {
        return VideoView()
    }

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
}
