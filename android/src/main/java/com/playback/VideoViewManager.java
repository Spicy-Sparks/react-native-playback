package com.playback;

import android.view.View;

import androidx.annotation.NonNull;

import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;

public class VideoViewManager extends SimpleViewManager<VideoView> {
  public static final String REACT_CLASS = "VideoView";

  @Override
  @NonNull
  public String getName() {
    return REACT_CLASS;
  }

  @Override
  @NonNull
  public VideoView createViewInstance(ThemedReactContext reactContext) {
    return new VideoView(reactContext);
  }

  @ReactProp(name = "playerId")
  public void setPlayerId(VideoView view, String playerId) {
    view.setPlayerId(playerId);
  }

  @ReactProp(name = "resizeMode")
  public void setResizeMode(VideoView view, String resizeMode) { view.setResizeMode(resizeMode); }
}
