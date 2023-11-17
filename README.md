# react-native-playback

React Native Playback

## Installation

```sh
npm install react-native-playback
```

## Usage

```js
import { VideoView, createPlayer } from 'react-native-playback'

const [ playerId, setPlayerId ] = useState<string | null>(null)

useEffect(() => {
  const player = createPlayer(() => {

    setPlayerId(player.getId())

    player.setSource({
      url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      headers: {
        'Host': 'google.com'
      }
    })

    player.pause()
    player.play()

    player.on('load', (data) => console.log("ON LOAD", data))
    player.on('error', (data) => console.log("ON ERROR", data))
    player.on('buffering', (data) => console.log("ON BUFFERING", data))
    player.on('timedMetadata', (data) => console.log("ON TIMED METADATA", data))
    player.on('stalled', (data) => console.log("ON STALLED", data))
    player.on('play', (data) => console.log("ON PLAY", data))
    player.on('pause', (data) => console.log("ON PAUSE", data))
    player.on('progress', (data) => console.log("ON PROGRESS", data))
    player.on('end', (data) => console.log("ON END", data))
    player.on('seek', (data) => console.log('ON SEEK', data))
    player.on('becomeNoisy', (data) => console.log("ON BECOME NOISY", data))
  })
}, [])

if(!playerId)
  return null

return <VideoView
    style={styles.container}
    playerId={playerId}
    style={{
      backgroundColor: 'black',
      width: 400,
      height: 300
    }}
  />
)
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
