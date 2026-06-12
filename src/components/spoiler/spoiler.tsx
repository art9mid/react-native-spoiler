import React, { useCallback, useRef, useState } from 'react'
import { Pressable, StyleSheet } from 'react-native'
import type { GestureResponderEvent } from 'react-native'
import { EaseView } from 'react-native-ease'
import { SpoilerOverlay } from '../spoiler-overlay'
import type { SpoilerProps } from './spoiler.types'
import type { NitroSpoiler as NitroSpoilerRef } from '../../specs/nitro-spoiler.nitro'

/**
 * Spoiler component. Wrap any content — text, images, whole blocks —
 * and it stays hidden behind an animated particle cloud until tapped.
 *
 * Everything animated runs natively: the dust simulation, finger-play
 * (hold/drag pushes particles around and never reveals), and the tap reveal —
 * particles are pulled into the touch point while an expanding radial mask
 * wipes the dust out and the content in.
 *
 * Each layer is customizable via `pressableProps`, `contentProps` (EaseView)
 * and `overlayProps` (SpoilerOverlay).
 */
export function Spoiler({
  hidden,
  defaultHidden = true,
  onHiddenChange,
  color,
  style,
  children,
  pressableProps,
  contentProps,
  overlayProps,
}: SpoilerProps) {
  const [internalHidden, setInternalHidden] = useState(defaultHidden)
  const isControlled = hidden !== undefined
  const isHidden = isControlled ? hidden : internalHidden

  const nativeRef = useRef<NitroSpoilerRef | null>(null)

  const setHidden = useCallback(
    (next: boolean) => {
      onHiddenChange?.(next)
      if (!isControlled) {
        setInternalHidden(next)
      }
    },
    [isControlled, onHiddenChange]
  )

  const userOnPress = pressableProps?.onPress
  const onPress = useCallback(
    (event: GestureResponderEvent) => {
      userOnPress?.(event)
      if (isHidden) {
        // native reveal: blast + radial wipe from the touch point.
        // reveal() returns false right after a finger-play drag — stay hidden.
        const { locationX, locationY } = event.nativeEvent
        const revealed = nativeRef.current?.reveal(locationX, locationY)
        if (revealed === false) {
          return
        }
        setHidden(false)
      } else {
        // conceal: native brings the dust back, content fades out
        setHidden(true)
      }
    },
    [isHidden, setHidden, userOnPress]
  )

  const hybridRef = useCallback((ref: NitroSpoilerRef) => {
    nativeRef.current = ref
  }, [])

  return (
    <Pressable {...pressableProps} onPress={onPress} style={style}>
      <EaseView
        {...contentProps}
        animate={{ opacity: isHidden ? 0 : 1, ...contentProps?.animate }}
        transition={
          contentProps?.transition ?? {
            type: 'timing',
            duration: isHidden ? 400 : 150,
            easing: 'linear',
          }
        }
      >
        {children}
      </EaseView>
      <SpoilerOverlay
        color={color}
        manageContentAlpha={true}
        {...overlayProps}
        visible={isHidden}
        hybridRef={hybridRef}
        style={[StyleSheet.absoluteFill, overlayProps?.style]}
      />
    </Pressable>
  )
}
