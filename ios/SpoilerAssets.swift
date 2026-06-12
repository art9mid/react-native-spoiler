import UIKit

enum SpoilerAssets {
    /// Speckle texture lives in the pod's resource bundle ("NitroSpoiler.bundle").
    /// Falls back to the main bundle for apps that bundle the asset directly.
    static let speckleImage: UIImage? = {
        let frameworkBundle = Bundle(for: BundleToken.self)
        if let url = frameworkBundle.url(forResource: "NitroSpoiler", withExtension: "bundle"),
           let bundle = Bundle(url: url),
           let image = UIImage(named: "textSpeckle_Normal", in: bundle, compatibleWith: nil) {
            return image
        }
        return UIImage(named: "textSpeckle_Normal", in: frameworkBundle, compatibleWith: nil)
            ?? UIImage(named: "textSpeckle_Normal")
    }()
}

private final class BundleToken {}
