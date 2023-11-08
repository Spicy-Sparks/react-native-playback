package com.playback;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.module.annotations.ReactModule;
import java.util.HashMap;
import java.util.Map;

@ReactModule(name = PlaybackModule.NAME)
public class PlaybackModule extends ReactContextBaseJavaModule {
  public static final String NAME = "Playback";
  public static Map<String, Player> players = new HashMap<>();

  public PlaybackModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @ReactMethod
  public void createPlayer(String playerId, Promise promise) {
    InitCallback callback = () -> promise.resolve(playerId);
    var player = new Player(getReactApplicationContext(), playerId, callback);
    players.put(playerId, player);
  }

  @ReactMethod
  public void disposePlayer(String playerId, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.dispose();
    players.remove(playerId);
    promise.resolve(null);
  }

  @ReactMethod
  public void setSource(String playerId, ReadableMap source, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.setSource(source);
    promise.resolve(null);
  }

  @ReactMethod
  public void play(String playerId, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.play();
    promise.resolve(null);
  }

  @ReactMethod
  public void pause(String playerId, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.pause();
    promise.resolve(null);
  }

  @ReactMethod
  public void setLoop(String playerId, boolean loop, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.setLoop(loop);
    promise.resolve(null);
  }

  @ReactMethod
  public void setVolume(String playerId, double volume, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.setVolume(volume);
    promise.resolve(null);
  }

  @ReactMethod
  public void seek(String playerId, ReadableMap seek, Promise promise) {
    var player = players.get(playerId);
    if(player == null) {
      promise.reject("E_PLAYER_NOT_FOUND", "playerId is invalid");
      return;
    }
    player.seek(seek);
    promise.resolve(null);
  }

  @ReactMethod
  public void addListener(String eventName) { }

  @ReactMethod
  public void removeListeners(Integer count) { }
}
