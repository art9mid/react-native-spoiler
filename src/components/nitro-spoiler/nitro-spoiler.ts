import type {
  NitroSpoilerProps,
  NitroSpoilerMethods,
} from '../../specs/nitro-spoiler.nitro'
import { getHostComponent } from 'react-native-nitro-modules'
import NitroSpoilerConfig from '../../../nitrogen/generated/shared/json/NitroSpoilerConfig.json'

export const NitroSpoiler = getHostComponent<
  NitroSpoilerProps,
  NitroSpoilerMethods
>('NitroSpoiler', () => NitroSpoilerConfig)
