package com.playback;

import android.annotation.SuppressLint;
import android.content.Context;
import android.view.ViewGroup;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.ui.AspectRatioFrameLayout;
import androidx.media3.ui.PlayerView;

@SuppressLint("ViewConstructor")
public class VideoView extends PlayerView {
  private String playerId;
  private Context context;

  private String resizeMode;

  public VideoView(Context context) {
    super(context);
    this.context = context;
    setUseController(false);
  }

  public void setPlayerId (String playerId) {
    this.playerId = playerId;
    Player player = PlaybackModule.players.get(playerId);
    if(player == null || player.player == null)
      return;
    runOnUiThread(() -> {
      if(player.player == null)
        return;
      setUseController(false);
      setPlayer(player.player);
      applyResizeMode();
    });
  }

  public void setResizeMode (String resizeMode) {
    runOnUiThread(() -> {
      this.resizeMode = resizeMode;
      applyResizeMode();
    });
  }

  @OptIn(markerClass = UnstableApi.class) public void applyResizeMode () {
    if (this.resizeMode == null) {
      this.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FILL);
      return;
    }

    switch (this.resizeMode) {
      case "contain":
        this.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIT);
        break;
      case "stretch": {
        this.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH);
        ViewGroup.LayoutParams layoutParams = this.getLayoutParams();
        layoutParams.height = ViewGroup.LayoutParams.MATCH_PARENT;
        this.setLayoutParams(layoutParams);
        break;
      }
      case "none":
      case "cover":
      default:
        this.setResizeMode(AspectRatioFrameLayout.RESIZE_MODE_FILL);
        break;
    }
  }
}
