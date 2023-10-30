package com.playback;

import android.annotation.SuppressLint;
import android.view.View;

import com.facebook.react.uimanager.ThemedReactContext;

@SuppressLint("ViewConstructor")
public class VideoView extends View {
  private String playerId;

  public VideoView(ThemedReactContext themedReactContext) {
    super(themedReactContext);
  }

  public void setPlayerId (String playerId) {
    this.playerId = playerId;
  }
}
