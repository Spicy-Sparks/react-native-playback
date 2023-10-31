package com.playback;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Handler;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;

import com.facebook.react.uimanager.ThemedReactContext;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.ui.PlayerView;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

@SuppressLint("ViewConstructor")
public class VideoView extends PlayerView {
  private String playerId;
  private Context context;

  public VideoView(Context context) {
    super(context);
    this.context = context;
  }

  public void setPlayerId (String playerId) {
    this.playerId = playerId;
    Player player = PlaybackModule.players.get(playerId);
    if(player == null || player.player == null)
      return;
    runOnUiThread(() -> {
      if(player.player == null)
        return;
      setPlayer(player.player);
    });
  }
}
