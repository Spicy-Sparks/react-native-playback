import { Platform, type EmitterSubscription } from 'react-native'
import Module, { emitter } from './module'

export type SourceType = {
  url: string,
  headers?: {
    [header: string]: string
  }
}

class Player {
  public type: string = 'direct'

  private playerId: string = ''
  private source: SourceType | null = null
  private volume: number = 1
  private paused: boolean = false
  private loop: boolean = false
  private toggledPlayPause: boolean = false
  private eventListeners: Record<string, Function[]> = {}
  private nativeEventSubscription: EmitterSubscription | null = null

  constructor(onCreated?: () => any) {
    this.playerId = this.generateId();
    (async () => {
      await this.mount()
      onCreated && onCreated()
    })()
  }
  
  private removeNativeEventSubscription() {
    if (this.nativeEventSubscription) {
      // @ts-ignore
      if(emitter.removeSubscription)
        // @ts-ignore
        emitter.removeSubscription(this.nativeEventSubscription)
      else
        this.nativeEventSubscription.remove()
    }
  }

  private async mount() {
    try {
      if(!this.playerId)
        this.playerId = this.generateId()
      this.nativeEventSubscription = emitter.addListener(
        'playerEvent',
        (data) => this.onNativeEvent(this.playerId, data)
      )
      await Module.createPlayer(this.playerId)
      this.emit('created')
    } catch (err) {
      this.removeNativeEventSubscription()
      this.playerId = ''
    }
  }

  public async dispose() {
    try {
      this.removeNativeEventSubscription()
      await Module.disposePlayer(this.playerId)
    } catch (err) {}
  }

  public getId() {
    return this.playerId
  }

  public setSource(data: SourceType & {
    autoplay?: boolean,
    volume?: number,
  }) {
    if (!this.playerId || !data || !data.url) return
    const { autoplay, volume, ...source } = data
    this.source = source
    if(typeof volume === 'number')
      this.volume = volume
    this.paused = !autoplay
    this.toggledPlayPause = false
    Module.setSource(this.playerId, data)
  }

  public getSource() {
    return this.source
  }

  public async play() {
    if (!this.playerId) return
    this.paused = false
    this.toggledPlayPause = true
    Module.play(this.playerId)
  }

  public async pause() {
    if (!this.playerId) return
    this.paused = true
    this.toggledPlayPause = true
    Module.pause(this.playerId)
  }

  public getPaused() {
    return this.paused
  }

  public setVolume(volume: number) {
    if (!this.playerId || typeof volume !== 'number') return
    this.volume = volume
    Module.setVolume(this.playerId, volume)
  }

  public getVolume() {
    return this.volume
  }

  public setLoop(loop: boolean) {
    if (!this.playerId || typeof loop !== 'boolean') return
    this.loop = loop
    Module.setLoop(this.playerId, loop)
  }

  public getLoop() {
    return this.loop
  }

  public async seek(time: { time: number, tolerance?: number }): Promise<{
    seeked: boolean
  }> {
    if (!this.playerId || !time || typeof time.time !== 'number')
      return Promise.reject(new Error("Invalid data"))
    return await Module.seek(this.playerId, time)
  }

  public fadeVolume(fade: { volume: number, duration?: number }) {
    if (!this.playerId || typeof fade.volume !== 'number') return
    if (!fade.duration || fade.duration < 0) fade.duration = 5
    this.volume = this.volume
    Module.fadeVolume(this.playerId, fade.volume, fade.duration)
  }

  private generateId() {
    return new Date().getTime().toString() + Math.floor(Math.random() * 100)
  }

  private onNativeEvent(thisPlayerId: string, data: any) {
    if (!data) return
    const { eventType, ...eventData } = data
    if (!eventType || eventData.playerId !== thisPlayerId) return
    switch (data.eventType) {
      case 'ON_LOAD':
        this.emit('load', eventData)
        return
      case 'ON_ERROR':
        this.emit('error', eventData)
        return
      case 'ON_BUFFERING':
        this.emit('buffering', eventData)
        return
      case 'ON_TIMED_METADATA':
        this.emit('timedMetadata', eventData)
        return
      case 'ON_STALLED':
        this.emit('stalled', eventData)
        return
      case 'ON_PLAY':
        if (Platform.OS === 'ios' && !this.toggledPlayPause)
          return
        this.paused = false
        this.emit('play', eventData)
        return
      case 'ON_PAUSE':
        if (Platform.OS === 'ios' && !this.toggledPlayPause)
          return
        this.paused = true
        this.emit('pause', eventData)
        return
      case 'ON_PROGRESS':
        this.emit('progress', eventData)
        return
      case 'ON_END':
        this.emit('end', eventData)
        return
      case 'ON_SEEK':
        this.emit('seek', eventData)
        return
      case 'ON_BECOME_NOISY':
        this.emit('becomeNoisy', eventData)
        return
      case 'ON_EXTERNAL_PLAYER':
        this.emit('externalPlayer', eventData)
        return
    }
  }

  public on(eventType: string, callback: (eventData: any) => void) {
    if (!this.eventListeners[eventType]) this.eventListeners[eventType] = []
    this.eventListeners[eventType]!.push(callback)
  }

  public off(eventType: string, callback: (eventData: any) => void) {
    const listeners = this.eventListeners[eventType]
    if (listeners) {
      const index = listeners.indexOf(callback)
      if (index !== -1) listeners.splice(index, 1)
    }
  }

  public clearEvents() {
    this.eventListeners = {}
  }

  private emit(eventType: string, eventData?: any) {
    const listeners = this.eventListeners[eventType]
    if (listeners) listeners.forEach((listener) => listener(eventData))
  }
}

export default Player