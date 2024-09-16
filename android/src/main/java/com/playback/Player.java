package com.playback;

import static androidx.media3.common.Player.STATE_BUFFERING;
import static androidx.media3.common.Player.STATE_ENDED;
import static androidx.media3.common.Player.STATE_IDLE;
import static androidx.media3.common.Player.STATE_READY;

import android.os.Handler;

import androidx.annotation.Nullable;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

public class Player {
  private ReactContext context;
  public String playerId = "";
  public ExoPlayer player;

  public PlayerView playerView;
  private boolean paused;
  private double volume;
  private boolean loop;

  private androidx.media3.common.Player.Listener eventsListener;
  private final Handler progressHandler = new Handler();
  private Runnable progressRunnable;

  private final Handler volumeFadeHandler = new Handler();
  private Runnable volumeFadeTimer = null;
  private double volumeFadeStart = 0;
  private float volumeFadeDuration = 3;
  private float volumeFadeTarget = 1;
  private float volumeFadeInitialVolume = 0;

  public Player (ReactContext reactContext, String playerId, InitCallback callback) {
    this.context = reactContext;

    runOnUiThread(() -> {
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
          runOnUiThread(() -> {
            if (player != null && player.isPlaying()) {
              WritableMap params = Arguments.createMap();
              params.putString("eventType", "ON_PROGRESS");
              params.putString("playerId", playerId);
              params.putDouble("currentTime", player.getCurrentPosition() / 1000);
              params.putDouble("duration", player.getDuration() / 1000);
              sendEvent(params);
              progressHandler.postDelayed(this, 500);
            }
          });
        }
      };

      this.eventsListener = new androidx.media3.common.Player.Listener() {
        private void sendEvent(@Nullable WritableMap params) {
          reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit("playerEvent", params);
        }

        @Override
        public void onPlaybackStateChanged(int playbackState) {
          androidx.media3.common.Player.Listener.super.onPlaybackStateChanged(playbackState);
          switch (playbackState) {
            case STATE_BUFFERING: {
              WritableMap params = Arguments.createMap();
              params.putString("eventType", "ON_BUFFERING");
              params.putString("playerId", playerId);
              sendEvent(params);
              break;
            }
            case STATE_READY: {
              runOnUiThread(() -> {
                if(player == null)
                  return;
                int videoWidth = 0;
                int videoHeight = 0;
                VideoSize videoSize = player.getVideoSize();
                if (videoSize != null) {
                  videoWidth = videoSize.width;
                  videoHeight = videoSize.height;
                }
                WritableMap params = Arguments.createMap();
                params.putString("eventType", "ON_LOAD");
                params.putString("playerId", playerId);
                params.putDouble("duration", player.getDuration() / 1000);
                params.putDouble("currentTime", player.getCurrentPosition() / 1000);
                params.putBoolean("canPlayReverse", true);
                params.putBoolean("canPlayFastForward", true);
                params.putBoolean("canPlaySlowForward", true);
                params.putBoolean("canPlaySlowReverse", true);
                params.putBoolean("canStepBackward", true);
                params.putBoolean("canStepForward", true);
                params.putInt("videoWidth", videoWidth);
                params.putInt("videoHeight", videoHeight);
                sendEvent(params);
              });
              break;
            }
            case STATE_ENDED: {
              WritableMap params = Arguments.createMap();
              params.putString("eventType", "ON_END");
              params.putString("playerId", playerId);
              sendEvent(params);
              break;
            }
            case STATE_IDLE: {
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
          androidx.media3.common.Player.Listener.super.onIsPlayingChanged(isPlaying);
          WritableMap params = Arguments.createMap();
          params.putString("eventType", isPlaying ? "ON_PLAY" : "ON_PAUSE");
          params.putString("playerId", playerId);
          sendEvent(params);

          if (isPlaying)
            progressHandler.post(progressRunnable);
          else
            progressHandler.removeCallbacks(progressRunnable);
        }

        @Override
        public void onPlayerError(PlaybackException error) {
          androidx.media3.common.Player.Listener.super.onPlayerError(error);
          WritableMap params = Arguments.createMap();
          params.putString("eventType", "ON_ERROR");
          params.putString("playerId", playerId);
          if(error != null) {
            params.putInt("errorCode", error.errorCode);
            params.putString("errorMessage", error.getMessage());
          }
          sendEvent(params);
        }

        @Override
        public void onPlayerErrorChanged(PlaybackException error) {
          androidx.media3.common.Player.Listener.super.onPlayerErrorChanged(error);
          WritableMap params = Arguments.createMap();
          params.putString("eventType", "ON_ERROR");
          params.putString("playerId", playerId);
          if(error != null) {
            params.putInt("errorCode", error.errorCode);
            params.putString("errorMessage", error.getMessage());
          }
          sendEvent(params);
        }

        @Override
        public void onPositionDiscontinuity(androidx.media3.common.Player.PositionInfo oldPosition, androidx.media3.common.Player.PositionInfo newPosition, int reason) {
          androidx.media3.common.Player.Listener.super.onPositionDiscontinuity(oldPosition, newPosition, reason);
          if(oldPosition.positionMs <= 0 && newPosition.positionMs <= 0)
            return;
          WritableMap params = Arguments.createMap();
          params.putString("eventType", "ON_SEEK");
          params.putString("playerId", playerId);
          params.putDouble("currentTime", (double) newPosition.positionMs / 1000);
          params.putDouble("seekTime", (double) newPosition.positionMs / 1000);
          sendEvent(params);
        }
      };

      this.player.addListener(eventsListener);

      callback.onCreated();
    });
  }

  public void dispose() {
    stopVolumeFade(false);
    runOnUiThread(() -> {
      if(this.player != null) {
        this.player.release();
        if(this.eventsListener != null)
          this.player.removeListener(this.eventsListener);
        this.player = null;
      }
    });
    progressHandler.removeCallbacks(progressRunnable);
    this.paused = false;
    this.loop = false;
    this.volume = 1;
  }

  public void setSource(ReadableMap source) {
    stopVolumeFade(false);

    runOnUiThread(() -> {
      if(this.player == null)
        return;

      MediaItem mediaItem = MediaItem.fromUri(source.getString("url"));
      this.player.setMediaItem(mediaItem);
      this.player.prepare();

      if (source.hasKey("autoplay") && source.getBoolean("autoplay")) {
        this.paused = false;
        this.player.setPlayWhenReady(true);
      } else {
        this.paused = true;
        this.player.setPlayWhenReady(false);
      }

      if (source.hasKey("volume")) {
        this.volume = source.getDouble("volume");
        this.player.setVolume((float) this.volume);
      }
    });
  }

  public void play() {
    this.paused = false;
    runOnUiThread(() -> {
      if(this.player == null)
        return;
      this.player.play();
    });
  }

  public void pause() {
    this.paused = true;
    runOnUiThread(() -> {
      if(this.player == null)
        return;
      this.player.pause();
    });
  }

  public void setVolume(double volume) {
    this.volume = volume;
    stopVolumeFade(false);
    runOnUiThread(() -> {
      if(this.player == null)
        return;
      this.player.setVolume((float) volume);
    });
  }

  public void setLoop(boolean loop) {
    this.loop = loop;
  }

  public void seek(ReadableMap seek, SeekCallback callback) {
    runOnUiThread(() -> {
      if(player == null) {
        callback.onSeekComplete(false);
        return;
      }
      var targetPosition = seek.getDouble("time");
      if(player.getCurrentPosition() / 1000 == targetPosition) {
        callback.onSeekComplete(false);
        return;
      }
      stopVolumeFade(true);
      this.player.seekTo((long) (targetPosition * 1000));
      callback.onSeekComplete(true);
    });
  }

  public void fadeVolume(float target, float duration) {
    runOnUiThread(() -> {
      if (duration <= 0 || player == null)
        return;

      if (volumeFadeTimer != null)
        stopVolumeFade(true);

      volumeFadeStart = System.currentTimeMillis();
      volumeFadeTarget = target;
      volumeFadeDuration = duration;
      volumeFadeInitialVolume = player.getVolume();

      this.volumeFadeTimer = new Runnable() {
        @Override
        public void run() {
          runOnUiThread(() -> {
            if (player == null || volumeFadeStart <= 0)
              return;

            var timePassed = (System.currentTimeMillis() - volumeFadeStart) / 1000 / volumeFadeDuration;

            if (player.getVolume() < volumeFadeTarget) {
              var volumeIncrement = Math.pow(timePassed, 2) * volumeFadeTarget;
              var newVolume = Math.min(volumeIncrement, volumeFadeTarget);
              player.setVolume((float) newVolume);
              volumeFadeHandler.postDelayed(this, 100);
            } else if (player.getVolume() > volumeFadeTarget) {
              var volumeIncrement = -Math.pow(timePassed, 2) + volumeFadeInitialVolume;
              var newVolume = Math.max(volumeIncrement, volumeFadeTarget);
              player.setVolume((float) newVolume);
              volumeFadeHandler.postDelayed(this, 100);
            } else {
              volume = volumeFadeTarget;
              stopVolumeFade(true);
            }
          });
        }
      };

      volumeFadeHandler.postDelayed(this.volumeFadeTimer, 1000);
    });
  }

  private void stopVolumeFade (boolean changeVolume) {
    volumeFadeStart = 0;
    if(volumeFadeTimer != null) {
      volumeFadeHandler.removeCallbacks(volumeFadeTimer);
      volumeFadeTimer = null;
    }
    volumeFadeInitialVolume = 0;
    if(changeVolume) {
      runOnUiThread(() -> {
        if (player == null)
          return;
        player.setVolume((float) volume);
      });
    }
  }
}
