# react-native-spoiler

Spoiler effect for React Native. Hide text, photos, or any view behind an
animated particle cloud — tap to reveal, hold and drag to play with the dust.

Built with [Nitro Modules](https://nitro.margelo.com) for fully native rendering:

- **iOS** — `CAEmitterLayer` particle emitter; the simulation runs entirely in
  Core Animation, off the main thread.
- **Android** — custom `View` with a pooled particle system batched into
  `Canvas.drawPoints` calls; 30 FPS with zero allocations per frame.

No work happens on the JS thread while the effect runs. Gestures (tap reveal,
finger-play) are handled natively too.

## Usage

```tsx
import { Spoiler } from 'react-native-spoiler'

// Text
<Spoiler>
  <Text>the butler did it!</Text>
</Spoiler>

// Photos — use white particles over images
<Spoiler color="#FFFFFF">
  <Image source={{ uri: photo }} style={{ width: 300, height: 200 }} />
</Spoiler>

// Any block
<Spoiler>
  <View>{/* anything */}</View>
</Spoiler>
```

Tap reveals: particles are pulled into the touch point while an expanding
radial mask wipes the dust out and the content in. Holding or dragging a
finger pushes the dust around without revealing.

### `<Spoiler />` props

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `hidden` | `boolean` | — | Controlled visibility. When set, tap-to-toggle is disabled. |
| `defaultHidden` | `boolean` | `true` | Initial visibility for uncontrolled usage. |
| `onHiddenChange` | `(hidden: boolean) => void` | — | Called when the user taps the spoiler. |
| `color` | `string` | black | Particle color as a hex string (e.g. `#FFFFFF`). |
| `style` | `ViewStyle` | — | Style for the wrapping `Pressable`. |

### `<SpoilerOverlay />` — compose it yourself

The standalone dust overlay. It absolutely fills its parent — drop it over any
content and manage reveal logic however you like:

```tsx
import { SpoilerOverlay } from 'react-native-spoiler'

<View>
  <Image source={photo} />
  {hidden && <SpoilerOverlay color="#FFFFFF" />}
</View>
```

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `visible` | `boolean` | `true` | Whether the effect is emitting. |
| `color` | `string` | black | Particle color as a hex string. |
| `manageContentAlpha` | `boolean` | `false` | Also wipe the covered sibling view in on reveal. |
| `hybridRef` | `(ref) => void` | — | Access the native object (`reveal(x, y)`, `touch(x, y)`, `release()`). |
| `style` | `ViewStyle` | absolute fill | Extra style on top of the fill. |

`NitroSpoiler` (the raw Nitro host component) is also exported if you need
full control over `isOn`, layout, and pointer events.

## Installation

```sh
npm install react-native-spoiler react-native-nitro-modules react-native-ease
cd ios && pod install
```

## Development

- `bun run specs` — regenerate Nitro bindings after changing `src/specs/*.nitro.ts`
- `bun run build` — typecheck + build `lib/` with builder-bob
- `example/` — demo app (`pod install` in `example/ios`, then run from Xcode / Android Studio)
