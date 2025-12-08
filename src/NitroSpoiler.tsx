import React from 'react'
import type {
  NitroSpoilerProps,
  NitroSpoilerMethods,
} from './specs/NitroSpoiler.nitro'
import { getHostComponent } from 'react-native-nitro-modules'
import NitroSpoilerConfig from '../nitrogen/generated/shared/json/NitroSpoilerConfig.json'

const Host = getHostComponent<NitroSpoilerProps, NitroSpoilerMethods>(
  'NitroSpoiler',
  () => NitroSpoilerConfig
)

export const NitroSpoiler = ({ ...props }: NitroSpoilerProps) => {
  return <Host {...props} />
}
