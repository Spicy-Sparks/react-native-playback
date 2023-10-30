package com.playback;

import android.os.Handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.MediaMetadata;
import com.google.android.exoplayer2.PlaybackException;
import com.google.android.exoplayer2.Timeline;

public class Player {
  public String playerId = "";
  public ExoPlayer player;
  private boolean paused;
  private double volume;
  private boolean loop;

  private boolean autoplay;
  private final com.google.android.exoplayer2.Player.Listener eventsListener;

  private Handler progressHandler = new Handler();
  private Runnable progressRunnable;

  public Player (ReactContext reactContext, String playerId) {
    this.playerId = playerId;
    this.player = new ExoPlayer.Builder(reactContext).build();

    this.progressRunnable = new Runnable() {
      private void sendEvent(@Nullable WritableMap params) {
        reactContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
          .emit("playerEvent", params);
      }

      @Override
      public void run() {
        if (player != null && player.isPlaying()) {
          WritableMap params = Arguments.createMap();
          params.putString("eventType", "ON_PROGRESS");
          params.putString("playerId", playerId);
          params.putDouble("currentTime", player.getCurrentPosition());
          params.putDouble("duration", player.getDuration());
          sendEvent(params);
          progressHandler.postDelayed(this, 500);
        }
      }
    };

    this.eventsListener = new com.google.android.exoplayer2.Player.Listener() {
      private void sendEvent(@Nullable WritableMap params) {
        reactContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
          .emit("playerEvent", params);
      }

      @Override
      public void onTimelineChanged(@NonNull Timeline timeline, int reason) {
        com.google.android.exoplayer2.Player.Listener.super.onTimelineChanged(timeline, reason);
      }

      @Override
      public void onMediaMetadataChanged(@NonNull MediaMetadata mediaMetadata) {
        com.google.android.exoplayer2.Player.Listener.super.onMediaMetadataChanged(mediaMetadata);
      }

      @Override
      public void onIsLoadingChanged(boolean isLoading) {
        com.google.android.exoplayer2.Player.Listener.super.onIsLoadingChanged(isLoading);
      }

      @Override
      public void onPlaybackStateChanged(int playbackState) {
        com.google.android.exoplayer2.Player.Listener.super.onPlaybackStateChanged(playbackState);
        switch (playbackState) {
          case com.google.android.exoplayer2.Player.STATE_BUFFERING: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_BUFFERING");
            params.putString("playerId", playerId);
            sendEvent(params);
            break;
          }
          case com.google.android.exoplayer2.Player.STATE_READY: {
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
            sendEvent(params);

            if(autoplay)
              player.play();

            break;
          }
          case com.google.android.exoplayer2.Player.STATE_ENDED: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_END");
            params.putString("playerId", playerId);
            sendEvent(params);
            break;
          }
          case com.google.android.exoplayer2.Player.STATE_IDLE: {
            WritableMap params = Arguments.createMap();
            params.putString("eventType", "ON_STALLED");
            params.putString("playerId", playerId);
            sendEvent(params);
            break;
          }
        }
      }

      @Override
      public void onIsPlayingChanged(boolean isPlaying) {
        com.google.android.exoplayer2.Player.Listener.super.onIsPlayingChanged(isPlaying);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", isPlaying ? "ON_PLAY" : "ON_PAUSE");
        params.putString("playerId", playerId);
        sendEvent(params);

        if(isPlaying)
          progressHandler.post(progressRunnable);
        else
          progressHandler.removeCallbacks(progressRunnable);
      }

      @Override
      public void onPlayerError(@NonNull PlaybackException error) {
        com.google.android.exoplayer2.Player.Listener.super.onPlayerError(error);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_ERROR");
        params.putString("playerId", playerId);
        params.putInt("errorCode", error.errorCode);
        params.putString("errorMessage", error.getMessage());
        sendEvent(params);
      }

      @Override
      public void onPlayerErrorChanged(@Nullable PlaybackException error) {
        com.google.android.exoplayer2.Player.Listener.super.onPlayerErrorChanged(error);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_ERROR");
        params.putString("playerId", playerId);
        params.putInt("errorCode", error.errorCode);
        params.putString("errorMessage", error.getMessage());
        sendEvent(params);
      }

      @Override
      public void onPositionDiscontinuity(@NonNull com.google.android.exoplayer2.Player.PositionInfo oldPosition, @NonNull com.google.android.exoplayer2.Player.PositionInfo newPosition, int reason) {
        com.google.android.exoplayer2.Player.Listener.super.onPositionDiscontinuity(oldPosition, newPosition, reason);
        WritableMap params = Arguments.createMap();
        params.putString("eventType", "ON_SEEK");
        params.putString("playerId", playerId);
        params.putDouble("seekTime", (double) newPosition.positionMs / 100);
        params.putDouble("seekTime", (double) newPosition.positionMs / 100);
        sendEvent(params);
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
    progressHandler.removeCallbacks(progressRunnable);
    this.paused = false;
    this.loop = false;
    this.volume = 1;
  }

  public void setSource(ReadableMap source) {
    MediaItem mediaItem = MediaItem.fromUri(source.getString("url"));
    this.player.setMediaItem(mediaItem);
    this.player.prepare();

    if(source.hasKey("autoplay") && source.getBoolean("autoplay")) {
      this.autoplay = true;
      this.paused = false;
      this.player.play();
    } else  {
      this.autoplay = false;
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
