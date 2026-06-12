import type { ViewProps } from 'react-native'
import type { NitroSpoiler as NitroSpoilerRef } from '../../specs/nitro-spoiler.nitro'

export interface SpoilerOverlayProps extends ViewProps {
  /**
   * Whether the particle effect is emitting. Defaults to `true`.
   */
  visible?: boolean
  /**
   * Particle color (hex string, e.g. `#FFFFFF`). Defaults to black.
   */
  color?: string
  /**
   * When `true`, the reveal also wipes the covered content (the sibling view
   * in the React hierarchy) in radially from the tap point.
   * Use when the overlay directly covers the content it hides.
   */
  manageContentAlpha?: boolean
  /**
   * Receives the underlying native hybrid object — call `reveal(x, y)` on it
   * to play the reveal animation from a touch point.
   */
  hybridRef?: (ref: NitroSpoilerRef) => void
}
