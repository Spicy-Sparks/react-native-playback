@objc(Playback)
class Playback: RCTEventEmitter {
    
    static var players = [String: Player]()

    @objc override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    @objc(createPlayer:resolve:reject:)
    func createPlayer(playerId: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        let player = Player(eventEmitter: self, playerId: playerId)
        Playback.players[playerId] = player
        resolve("")
    }

    @objc(disposePlayer:resolve:reject:)
    func disposePlayer(playerId: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.dispose()
        Playback.players.removeValue(forKey: playerId)
        resolve(nil)
    }

    @objc(setSource:source:resolve:reject:)
    func setSource(playerId: String, source: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.setSource(source)
        resolve(nil)
    }

    @objc(play:resolve:reject:)
    func play(playerId: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.play()
        resolve(nil)
    }

    @objc(pause:resolve:reject:)
    func pause(playerId: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.pause()
        resolve(nil)
    }

    @objc(setVolume:volume:resolve:reject:)
    func setVolume(playerId: String, volume: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.setVolume(volume)
        resolve(nil)
    }

    @objc(setLoop:loop:resolve:reject:)
    func setLoop(playerId: String, loop: Bool, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.setLoop(loop)
        resolve(nil)
    }

    @objc(seek:seek:resolve:reject:)
    func seek(playerId: String, seek: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let player = Playback.players[playerId] else {
            reject("E_PLAYER_NOT_FOUND", "playerId is invalid", nil)
            return
        }
        player.seek(seek)
        resolve(nil)
    }

    override func supportedEvents() -> [String]! {
        return ["playerEvent"]
    }
}
