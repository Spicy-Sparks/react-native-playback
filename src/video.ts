import { requireNativeComponent, UIManager, Platform } from 'react-native';
import type { ImageProps, ViewProps } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-playback' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

type VideoViewProps = {
  playerId: string;
  resizeMode?: ImageProps['resizeMode'];
  style?: ViewProps['style'];
};

export default UIManager.getViewManagerConfig('VideoView') != null
  ? requireNativeComponent<VideoViewProps>('VideoView')
  : () => {
      throw new Error(LINKING_ERROR);
    };
