import React from 'react'
import { StyleSheet } from 'react-native'
import { callback } from 'react-native-nitro-modules'
import { NitroSpoiler } from '../nitro-spoiler'
import type { SpoilerOverlayProps } from './spoiler-overlay.types'

/**
 * The raw spoiler dust overlay.
 *
 * Absolutely fills its parent — drop it over any content:
 *
 * ```tsx
 * <View>
 *   <Image source={photo} />
 *   <SpoilerOverlay color="#FFFFFF" />
 * </View>
 * ```
 *
 * Accepts all React Native view props, forwarded to the native view.
 */
export function SpoilerOverlay({
  visible = true,
  color,
  manageContentAlpha = false,
  hybridRef,
  style,
  pointerEvents,
  ...viewProps
}: SpoilerOverlayProps) {
  return (
    <NitroSpoiler
      {...viewProps}
      isOn={visible}
      color={color}
      managesContentAlpha={manageContentAlpha}
      hybridRef={hybridRef ? callback(hybridRef) : undefined}
      style={[StyleSheet.absoluteFill, style]}
      // while hidden, the native view handles touches itself for finger-play
      // (taps still bubble to wrapping Pressables through RN's touch system);
      // once revealed it must not block the content underneath
      pointerEvents={pointerEvents ?? (visible ? 'auto' : 'none')}
    />
  )
}
