import type { EmitterSubscription } from 'react-native'
import Module, { emitter } from './module'

export type SourceType = {
  url: string
  headers?: {
    [header: string]: string
  }
}

class Player {
  private playerId: string = ''
  private source: SourceType | null = null
  private volume: number = 1
  private loop: boolean = false
  private eventListeners: Record<string, Function[]> = {}
  private nativeEventSubscription: EmitterSubscription | null = null

  constructor(onCreated?: () => any) {
    this.playerId = this.generateId();
    (async () => {
      await this.mount()
      onCreated && onCreated()
    })()
  }

  async mount() {
    try {
      if(!this.playerId)
        this.playerId = this.generateId()
      await Module.createPlayer(this.playerId)
      this.nativeEventSubscription = emitter.addListener(
        'playerEvent',
        (data) => this.onNativeEvent(this.playerId, data)
      )
      this.emit('created')
    } catch (err) {
      this.playerId = ''
    }
  }

  async disponse() {
    try {
      if (this.nativeEventSubscription)
        emitter.removeSubscription(this.nativeEventSubscription)
      await Module.disponsePlayer(this.playerId)
    } catch (err) {}
  }

  getId() {
    return this.playerId
  }

  setSource(source: SourceType) {
    if (!this.playerId || !source) return
    this.source = { ...source }
    Module.setSource(this.playerId, source)
  }

  getSource() {
    return this.source
  }

  play() {
    if (!this.playerId) return
    Module.play(this.playerId)
  }

  pause() {
    if (!this.playerId) return
    Module.pause(this.playerId)
  }

  setVolume(volume: number) {
    if (!this.playerId || typeof volume !== 'number') return
    this.volume = volume
    Module.setVolume(this.playerId, volume)
  }

  getVolume() {
    return this.volume
  }

  setLoop(loop: boolean) {
    if (!this.playerId || typeof loop !== 'boolean') return
    this.loop = loop
    Module.setLoop(this.playerId, loop)
  }

  getLoop() {
    return this.loop
  }

  seek(time: { time: number, tolerance?: number }) {
    if (!this.playerId || !time || typeof time.time !== 'number') return
    Module.seek(this.playerId, time)
  }

  generateId() {
    return new Date().getTime().toString() + Math.floor(Math.random() * 100)
  }

  onNativeEvent(thisPlayerId: string, data: any) {
    if (!data) return
    const { playerId, eventType, ...eventData } = data
    if (!eventType || playerId !== thisPlayerId) return
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
        this.emit('play', eventData)
        return
      case 'ON_PAUSE':
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
    }
  }

  on(eventType: string, callback: (eventData: any) => void) {
    if (!this.eventListeners[eventType]) this.eventListeners[eventType] = []
    this.eventListeners[eventType]!.push(callback)
  }

  off(eventType: string, callback: (eventData: any) => void) {
    const listeners = this.eventListeners[eventType]
    if (listeners) {
      const index = listeners.indexOf(callback)
      if (index !== -1) listeners.splice(index, 1)
    }
  }

  private emit(eventType: string, eventData?: any) {
    const listeners = this.eventListeners[eventType]
    if (listeners) listeners.forEach((listener) => listener(eventData))
  }
}

export default Player
