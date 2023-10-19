package com.playback;

import android.content.Context;
import androidx.annotation.Nullable;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Timeline;
import androidx.media3.exoplayer.ExoPlayer;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class Player {
  public String playerId = "";
  public ExoPlayer player;
  private boolean paused;
  private double volume;
  private boolean loop;
  private androidx.media3.common.Player.Listener eventsListener;

  public Player (ReactContext reactContext, String playerId) {
    this.playerId = playerId;
    this.player = new ExoPlayer.Builder(reactContext).build();
    this.eventsListener = new androidx.media3.common.Player.Listener() {
      private void sendEvent(String eventName,
                             @Nullable WritableMap params) {
        reactContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
          .emit(eventName, params);
      }

      @Override
      public void onTimelineChanged(Timeline timeline, int reason) {
        androidx.media3.common.Player.Listener.super.onTimelineChanged(timeline, reason);
      }

      @Override
      public void onMediaMetadataChanged(MediaMetadata mediaMetadata) {
        androidx.media3.common.Player.Listener.super.onMediaMetadataChanged(mediaMetadata);
      }

      @Override
      public void onIsLoadingChanged(boolean isLoading) {
        androidx.media3.common.Player.Listener.super.onIsLoadingChanged(isLoading);
      }

      @Override
      public void onPlaybackStateChanged(int playbackState) {
        androidx.media3.common.Player.Listener.super.onPlaybackStateChanged(playbackState);
        switch (playbackState) {
          case androidx.media3.common.Player.STATE_BUFFERING: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_BUFFERING");
            params.putString("playerId", playerId);
            sendEvent("playerEvent", params);
            break;
          }
          case androidx.media3.common.Player.STATE_READY: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_LOAD");
            params.putString("playerId", playerId);
            params.putDouble("duration", player.getDuration());
            params.putDouble("currentTime", player.getCurrentPosition());
            params.putBoolean("canPlayReverse", true);
            params.putBoolean("canPlayFastForward", true);
            params.putBoolean("canPlaySlowForward", true);
            params.putBoolean("canPlaySlowReverse", true);
            params.putBoolean("canStepBackward", true);
            params.putBoolean("canStepForward", true);
            sendEvent("playerEvent", params);
            break;
          }
          case androidx.media3.common.Player.STATE_ENDED: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_END");
            params.putString("playerId", playerId);
            sendEvent("playerEvent", params);
            break;
          }
          case androidx.media3.common.Player.STATE_IDLE: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_STALLED");
            params.putString("playerId", playerId);
            sendEvent("playerEvent", params);
            break;
          }
        }
      }

      @Override
      public void onIsPlayingChanged(boolean isPlaying) {
        androidx.media3.common.Player.Listener.super.onIsPlayingChanged(isPlaying);
      }

      @Override
      public void onPlayerError(PlaybackException error) {
        androidx.media3.common.Player.Listener.super.onPlayerError(error);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_ERROR");
        params.putString("playerId", playerId);
        params.putInt("errorCode", error.errorCode);
        params.putString("errorMessage", error.getMessage());
        sendEvent("playerEvent", params);
      }

      @Override
      public void onPlayerErrorChanged(@Nullable PlaybackException error) {
        androidx.media3.common.Player.Listener.super.onPlayerErrorChanged(error);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_ERROR");
        params.putString("playerId", playerId);
        params.putInt("errorCode", error.errorCode);
        params.putString("errorMessage", error.getMessage());
        sendEvent("playerEvent", params);
      }

      @Override
      public void onPositionDiscontinuity(androidx.media3.common.Player.PositionInfo oldPosition, androidx.media3.common.Player.PositionInfo newPosition, int reason) {
        androidx.media3.common.Player.Listener.super.onPositionDiscontinuity(oldPosition, newPosition, reason);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_SEEK");
        params.putString("playerId", playerId);
        params.putDouble("seekTime", newPosition.positionMs / 100);
        params.putDouble("seekTime", newPosition.positionMs / 100);
        sendEvent("playerEvent", params);
      }
    };
    this.player.addListener(eventsListener);
  }

  public void dispose() {
    if(this.player != null) {
      if(this.eventsListener != null)
        this.player.addListener(this.eventsListener);
      this.player = null;
    }

    this.paused = false;
    this.loop = false;
    this.volume = 1;
  }

  public void setSource(ReadableMap source) {
    MediaItem mediaItem = MediaItem.fromUri(source.getString("url"));
    this.player.setMediaItem(mediaItem);
    this.player.prepare();

    if(source.hasKey("autoplay") && source.getBoolean("autoplay")) {
      this.paused = false;
      this.player.play();
    } else  {
      this.paused = true;
      this.player.pause();
    }

    if(source.hasKey("volume")) {
      this.volume = source.getDouble("volume");
      this.player.setVolume((float) this.volume);
    }
  }

  public void play() {
    this.paused = false;
    if(this.player == null)
      return;
    this.player.play();
  }

  public void pause() {
    this.paused = true;
    if(this.player == null)
      return;
    this.player.pause();
  }

  public void setVolume(double volume) {
    this.volume = volume;
    if(this.player == null)
      return;
    this.player.setVolume((float) volume);
  }

  public void setLoop(boolean loop) {
    this.loop = loop;
  }

  public void seek(ReadableMap seek) {
    if(this.player == null)
      return;
    this.player.seekTo((long) (seek.getDouble("time") * 1000));
  }
}
