import Foundation
import UIKit
import NitroModules

class EmitterView: UIView {

    override class var layerClass: AnyClass {
        CAEmitterLayer.self
    }

    override var layer: CAEmitterLayer {
        super.layer as! CAEmitterLayer
    }
}

/// Spoiler particle ("dust") effect, ported from Telegram-iOS InvisibleInkDustNode.
/// https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/InvisibleInkDustNode/Sources/InvisibleInkDustNode.swift
class SpoilerEmitterView: EmitterView {

    private static let cellName = "dustCell"

    private let supportsBehaviors: Bool

    // native finger-play tracking: no JS involvement per move
    private var touchStart: CGPoint = .zero
    private var didDrag = false
    private var lastDragEndTime: CFTimeInterval = 0

    var isOn: Bool = false {
        didSet {
            guard isOn != oldValue else { return }
            if isOn {
                cancelReveal()
                layer.beginTime = CACurrentMediaTime()
                layer.birthRate = 1
            } else {
                layer.birthRate = 0
            }
        }
    }

    /// When enabled, the reveal also wipes the covered content in radially
    /// from the tap point, by putting a transient mask on the sibling content
    /// view's layer (Fabric never writes layer.mask, so this is safe — unlike
    /// alpha, which React resets on prop updates).
    var managesContentAlpha: Bool = false

    /// The React view this overlay covers: our wrapper (RCTViewComponentView)
    /// and the content view are children of the same parent.
    private var contentSibling: UIView? {
        guard let wrapper = superview, let parent = wrapper.superview else { return nil }
        return parent.subviews.first { $0 !== wrapper }
    }


    var particleColor: UIColor = .black {
        didSet {
            layer.setValue(particleColor.cgColor, forKeyPath: "emitterCells.\(Self.cellName).color")
        }
    }

    override init(frame: CGRect) {
        let alphaBehavior = EmitterBehavior.make(type: "valueOverLife")
        let fingerAttractor = EmitterBehavior.make(type: "simpleAttractor")
        supportsBehaviors = alphaBehavior != nil && fingerAttractor != nil

        super.init(frame: frame)

        backgroundColor = .clear
        isOpaque = false
        // touches are handled natively for finger-play; React's touch system
        // still sees them (its root gesture handler doesn't cancel touches),
        // so a wrapping Pressable keeps working for tap-to-reveal
        isUserInteractionEnabled = true

        let cell = CAEmitterCell()
        cell.name = Self.cellName
        cell.contents = SpoilerAssets.speckleImage?.cgImage
        cell.color = particleColor.cgColor
        cell.contentsScale = 1.8
        cell.emissionRange = .pi * 2
        cell.lifetime = 1.0
        cell.scale = 0.5
        cell.velocityRange = 20
        cell.alphaRange = 1
        cell.setValue("point", forKey: "particleType")
        cell.setValue(3.0, forKey: "mass")
        cell.setValue(2.0, forKey: "massRange")

        layer.masksToBounds = true
        layer.allowsGroupOpacity = true
        layer.lifetime = 1
        layer.emitterShape = .rectangle
        layer.birthRate = 0
        layer.seed = arc4random()

        if supportsBehaviors, let alphaBehavior, let fingerAttractor {
            // Telegram's alpha-over-life curve: fade in, peak, fade out —
            // without it particles pop in at full alpha.
            alphaBehavior.setValue("color.alpha", forKey: "keyPath")
            alphaBehavior.setValue([0.0, 0.0, 1.0, 0.0, -1.0], forKey: "values")
            alphaBehavior.setValue(true, forKey: "additive")

            // Pushes particles away from the touch point during reveal.
            fingerAttractor.setValue("fingerAttractor", forKey: "name")

            layer.setValue([fingerAttractor, alphaBehavior], forKey: "emitterBehaviors")
            layer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
            layer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        } else {
            // fallback for OS versions without CAEmitterBehavior: fade out only
            cell.alphaSpeed = -1
        }
        layer.emitterCells = [cell]

        setupFingerPlayRecognizer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.emitterPosition = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        layer.emitterSize = bounds.size

        // Telegram scales emission with covered area (InvisibleInkDustNode: square * 0.35)
        let area = Float(bounds.width * bounds.height)
        layer.setValue(min(100_000, area * 0.35), forKeyPath: "emitterCells.\(Self.cellName).birthRate")

        if supportsBehaviors {
            let radius = max(bounds.width, bounds.height)
            layer.setValue(radius, forKeyPath: "emitterBehaviors.fingerAttractor.radius")
            layer.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        }
    }

    /// Finger-play (iMessage invisible-ink style): a repulsive field follows
    /// the finger and pushes dust away around it.
    func touch(at position: CGPoint) {
        guard supportsBehaviors, isOn else { return }
        let radius = max(120.0, min(bounds.width, bounds.height) * 0.5)
        layer.setValue(-10.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        layer.setValue(radius, forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        layer.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        layer.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
        layer.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
    }

    // named endTouch — `release()` collides with NSObject's unavailable ARC selector
    func endTouch() {
        guard supportsBehaviors else { return }
        layer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
    }

    // MARK: native finger-play — driven by a long-press recognizer, not raw
    // touches: a scroll view cancels content touches when its pan begins, but
    // gesture recognizers keep tracking, so holding the spoiler survives
    // small scrolls

    func setupFingerPlayRecognizer() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(onFingerPlay(_:)))
        recognizer.minimumPressDuration = 0.12
        recognizer.allowableMovement = .greatestFiniteMagnitude
        recognizer.cancelsTouchesInView = false
        addGestureRecognizer(recognizer)
    }

    @objc private func onFingerPlay(_ recognizer: UILongPressGestureRecognizer) {
        guard isOn || recognizer.state != .began else { return }
        let point = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            touchStart = point
            didDrag = false
            touch(at: point)
        case .changed:
            if !didDrag, hypot(point.x - touchStart.x, point.y - touchStart.y) > 10 {
                didDrag = true
            }
            touch(at: point)
        case .ended, .cancelled, .failed:
            endTouch()
            if didDrag {
                lastDragEndTime = CACurrentMediaTime()
            }
            didDrag = false
        default:
            break
        }
    }

    /// `true` when a reveal should proceed — `false` right after a finger-play
    /// drag (a drag is play, not a tap). Safe to call from any thread.
    var canReveal: Bool {
        CACurrentMediaTime() - lastDragEndTime > 0.3
    }

    /// Telegram's tap reveal (InvisibleInkDustNode `tap(_:)`): particles are
    /// pulled into the touch point, the dust is wiped out by an expanding
    /// radial mask, and the content is wiped in from the same point.
    func reveal(at position: CGPoint) {
        let size = bounds.size
        guard size.width > 0, size.height > 0, canReveal else { return }

        layer.birthRate = 0
        endTouch()

        if supportsBehaviors {
            let radius = max(size.width, size.height)
            layer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
            layer.setValue(radius, forKeyPath: "emitterBehaviors.fingerAttractor.radius")
            layer.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
            layer.setValue(position, forKeyPath: "emitterBehaviors.fingerAttractor.position")
            layer.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.layer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            }
        }

        // Telegram: expansion is faster/larger when tapping near an edge
        let xFactor = (position.x / size.width - 0.5) * 2
        let yFactor = (position.y / size.height - 0.5) * 2
        let maxFactor = max(abs(xFactor), abs(yFactor))
        var scaleAddition = maxFactor * 4
        var durationAddition = -maxFactor * 0.2
        if size.width / size.height < 0.7 {
            scaleAddition *= 5
            durationAddition *= 2
        }
        let wipeDuration = 0.55 + durationAddition
        let wipeScale = 10.5 + scaleAddition

        // dust mask: white fill (all visible) + inverse spot growing from the
        // tap, punching the dust out
        cancelReveal()
        let container = UIView(frame: bounds)
        container.backgroundColor = .clear

        let dustSpot = UIImageView(image: Self.makeSpotImage(size: size, position: position, inverse: true))
        dustSpot.contentMode = .scaleToFill
        dustSpot.frame = CGRect(x: 0, y: 0, width: size.width * 3, height: size.height * 3)
        dustSpot.layer.anchorPoint = CGPoint(x: position.x / size.width, y: position.y / size.height)
        dustSpot.layer.position = position

        let fill = UIView(frame: bounds)
        fill.backgroundColor = .white

        container.addSubview(dustSpot)
        container.addSubview(fill)
        maskContainer = container
        mask = container

        dustSpot.layer.add(Self.scaleAnimation(to: wipeScale, duration: wipeDuration), forKey: "reveal")

        let fillFade = CABasicAnimation(keyPath: "opacity")
        fillFade.fromValue = 1.0
        fillFade.toValue = 0.0
        fillFade.duration = 0.15
        fillFade.isRemovedOnCompletion = false
        fillFade.fillMode = .forwards
        fill.layer.add(fillFade, forKey: "fade")

        // content wipe: a transient mask on the sibling — the content appears
        // radially from the tap point (Telegram wipes its text node the same way)
        if managesContentAlpha, let content = contentSibling {
            let contentSpot = CALayer()
            contentSpot.contents = Self.makeSpotImage(size: size, position: position, inverse: false)?.cgImage
            contentSpot.frame = CGRect(x: 0, y: 0, width: size.width * 3, height: size.height * 3)
            contentSpot.anchorPoint = CGPoint(x: position.x / size.width, y: position.y / size.height)
            contentSpot.position = position
            content.layer.mask = contentSpot
            contentMaskedView = content

            contentSpot.add(Self.scaleAnimation(to: wipeScale, duration: wipeDuration), forKey: "reveal")
            DispatchQueue.main.asyncAfter(deadline: .now() + wipeDuration) { [weak self] in
                self?.clearContentMask()
            }
        }
    }

    private static func scaleAnimation(to scale: CGFloat, duration: CFTimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.3333
        animation.toValue = scale
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        return animation
    }

    private var maskContainer: UIView?
    private weak var contentMaskedView: UIView?

    private func clearContentMask() {
        contentMaskedView?.layer.mask = nil
        contentMaskedView = nil
    }

    private func cancelReveal() {
        maskContainer?.removeFromSuperview()
        maskContainer = nil
        mask = nil
        clearContentMask()
    }

    /// Telegram's generateMaskImage: a small radial gradient spot at the touch
    /// point — it gets scaled up to wipe. Normal: opaque inside (reveals the
    /// content); inverse: transparent inside (punches out the dust).
    private static func makeSpotImage(size: CGSize, position: CGPoint, inverse: Bool) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.clear(CGRect(origin: .zero, size: size))
            let startAlpha: CGFloat = inverse ? 0 : 1
            let endAlpha: CGFloat = inverse ? 1 : 0
            var locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
            let colors: [CGColor] = [
                UIColor(white: 1, alpha: startAlpha).cgColor,
                UIColor(white: 1, alpha: startAlpha).cgColor,
                UIColor(white: 1, alpha: endAlpha).cgColor,
                UIColor(white: 1, alpha: endAlpha).cgColor,
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations) else {
                return
            }
            let radius = min(10.0, min(size.width, size.height) * 0.4)
            context.drawRadialGradient(
                gradient,
                startCenter: position, startRadius: 0,
                endCenter: position, endRadius: radius,
                options: .drawsAfterEndLocation
            )
        }
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

}

final class HybridNitroSpoiler: HybridNitroSpoilerSpec {

    private let emitterView = SpoilerEmitterView()

    var isOn: Bool = false {
        didSet {
            emitterView.isOn = isOn
        }
    }

    var color: String? = nil {
        didSet {
            guard let color else { return }
            emitterView.particleColor = UIColor(hexString: color) ?? .black
        }
    }

    var managesContentAlpha: Bool? = false {
        didSet {
            emitterView.managesContentAlpha = managesContentAlpha ?? false
        }
    }

    func reveal(x: Double, y: Double) -> Bool {
        guard emitterView.canReveal else {
            return false
        }
        // hybrid methods are called from the JS thread; UIKit needs main
        DispatchQueue.main.async { [emitterView] in
            emitterView.reveal(at: CGPoint(x: x, y: y))
        }
        return true
    }

    func touch(x: Double, y: Double) {
        DispatchQueue.main.async { [emitterView] in
            emitterView.touch(at: CGPoint(x: x, y: y))
        }
    }

    func release() {
        DispatchQueue.main.async { [emitterView] in
            emitterView.endTouch()
        }
    }

    var view: UIView {
        emitterView
    }
}

