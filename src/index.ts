import Player from './player';

export { default as Player } from './player';
export { default as VideoView } from './video';

export function createPlayer(onCreated?: () => any) {
  return new Player(onCreated);
}
