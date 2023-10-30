package com.playback;

import android.annotation.SuppressLint;
import android.view.View;

import com.facebook.react.uimanager.ThemedReactContext;
import com.google.android.exoplayer2.ui.PlayerView;

@SuppressLint("ViewConstructor")
public class VideoView extends PlayerView {
  private String playerId;

  public VideoView(ThemedReactContext themedReactContext) {
    super(themedReactContext);
  }

  public void setPlayerId (String playerId) {
    this.playerId = playerId;
    Player player = PlaybackModule.players.get(playerId);
    if(player == null || player.player == null)
      return;
    try {
      this.setPlayer(player.player);
    }
    catch (Exception ignored) {

    }
  }
}
