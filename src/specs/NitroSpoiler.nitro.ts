import type {
  HybridView,
  HybridViewProps,
  HybridViewMethods,
} from 'react-native-nitro-modules'

export interface NitroSpoilerProps extends HybridViewProps {
  revealed?: boolean
  coverColor?: string
  tintColor?: string
}

export interface NitroSpoilerMethods extends HybridViewMethods {
}

export type NitroSpoiler = HybridView<NitroSpoilerProps, NitroSpoilerMethods>
