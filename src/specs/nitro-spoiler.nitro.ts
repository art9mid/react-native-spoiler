import type {
  HybridView,
  HybridViewProps,
  HybridViewMethods,
} from 'react-native-nitro-modules'

export interface NitroSpoilerProps extends HybridViewProps {
  isOn: boolean
  color?: string
  /**
   * When `true`, the native side also drives the opacity of the sibling
   * content view (the view the overlay covers): hidden on `isOn`, faded in
   * on reveal.
   * No JS-side animation needed.
   */
  managesContentAlpha?: boolean
}

export interface NitroSpoilerMethods extends HybridViewMethods {
  /**
   * Trigger the reveal animation from the given point (in view
   * coordinates): particles are blasted away from the touch and the dust is
   * wiped out by an expanding radial mask.
   */
  /**
   * Returns `false` when the gesture was finger-play (a drag) and the reveal
   * was suppressed — keep the content hidden in that case.
   */
  reveal(x: number, y: number): boolean
  /**
   * Finger is touching/moving at the given point (view coordinates) — dust is
   * pushed away around the finger, iMessage invisible-ink style.
   */
  touch(x: number, y: number): void
  /**
   * Finger lifted — the dust field returns to normal.
   */
  release(): void
}

export type NitroSpoiler = HybridView<NitroSpoilerProps, NitroSpoilerMethods>
