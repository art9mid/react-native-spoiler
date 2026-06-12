import type { ComponentProps, ReactNode } from 'react'
import type { PressableProps, StyleProp, ViewStyle } from 'react-native'
import type { EaseView } from 'react-native-ease'
import type { SpoilerOverlayProps } from '../spoiler-overlay'

type EaseViewProps = ComponentProps<typeof EaseView>

export interface SpoilerProps {
  /**
   * Controlled visibility. When set, the component no longer toggles itself on tap.
   */
  hidden?: boolean
  /**
   * Initial visibility for uncontrolled usage. Defaults to `true` (content hidden).
   */
  defaultHidden?: boolean
  /**
   * Called when the user taps the spoiler to reveal/hide it.
   */
  onHiddenChange?: (hidden: boolean) => void
  /**
   * Particle color (hex string, e.g. `#FFFFFF`). Defaults to black.
   */
  color?: string
  style?: StyleProp<ViewStyle>
  children: ReactNode
  /**
   * Extra props for the wrapping `Pressable`. `onPress` is composed with the
   * internal reveal/conceal handler (yours runs first).
   */
  pressableProps?: Omit<PressableProps, 'style'>
  /**
   * Extra props for the `EaseView` animating the content. `animate` and
   * `transition` are merged with the internal reveal/conceal defaults.
   * Note: setting `animate.opacity` overrides the hide/show behavior.
   */
  contentProps?: Partial<EaseViewProps>
  /**
   * Extra props for the dust `SpoilerOverlay`. `visible` and `hybridRef` are
   * managed internally.
   */
  overlayProps?: Omit<SpoilerOverlayProps, 'visible' | 'hybridRef'>
}
