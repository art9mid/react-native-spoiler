import Foundation
import UIKit
import NitroModules
import QuartzCore

final class SpoilerEmitterLayer: CALayer {
    private var emitterCell: CAEmitterCell?
    private var emitterLayer: CAEmitterLayer?

    override init() {
        super.init()
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let c = CAEmitterCell()
        c.contents = createDot()

        c.color = UIColor.black.cgColor
        c.emissionRange = .pi * 2
        c.lifetime = 1
        c.scale = 0.5
        c.velocityRange = 20
        c.alphaRange = 1
        c.birthRate = 4000
        emitterCell = c

        let l = CAEmitterLayer()
        l.emitterShape = .rectangle
        l.emitterCells = [c]
        emitterLayer = l
        addSublayer(l)
    }

    private func createDot() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        .cgImage
    }

    func updateSize(_ size: CGSize) {
        guard let emitterLayer else {
            return
        }
        emitterLayer.frame = CGRect(origin: .zero, size: size)
        emitterLayer.emitterSize = size
        emitterLayer.emitterPosition = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func updateTint(_ color: UIColor) {
        emitterCell?.color = color.cgColor
    }

    func setActive(_ v: Bool) {
        emitterLayer?.birthRate = v ? 1 : 0
    }
}

final class NitroSpoilerView: UIView {
    private let emitter = SpoilerEmitterLayer()
    private let coverView = UIView()
    private let maskLayer = CAShapeLayer()

    var onReveal: (() -> Void)?

    private(set) var isRevealed = false
    private var animating = false

    var tint: UIColor = .white {
        didSet {
            emitter.updateTint(tint)
        }
    }

    var cover: UIColor = .black {
        didSet {
            coverView.backgroundColor = cover
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.addSublayer(emitter)
        addSubview(coverView)
        layer.mask = maskLayer
        maskLayer.fillColor = UIColor.white.cgColor

        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)

        emitter.setActive(true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.updateSize(bounds.size)
        coverView.frame = bounds

        if !animating && !isRevealed {
            maskLayer.path = UIBezierPath(rect: bounds).cgPath
        }
    }

    func reveal() {
        guard !isRevealed, !animating else {
            return
        }
        animating = true
        isRevealed = true

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let start = UIBezierPath(ovalIn: CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2))
        let r = hypot(bounds.width, bounds.height)
        let end = UIBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = start.cgPath
        anim.toValue = end.cgPath
        anim.duration = 0.45
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        maskLayer.path = end.cgPath
        maskLayer.add(anim, forKey: "revealAnim")

        UIView.animate(withDuration: 0.45, delay: 0, options: .curveEaseOut) {
            self.coverView.alpha = 0
            self.emitter.opacity = 0
        } completion: { [weak self] _ in
            guard let self = self else {
                return
            }
            self.emitter.setActive(false)
            self.animating = false
            self.onReveal?()
        }
    }

    func reset() {
        animating = false
        isRevealed = false
        maskLayer.removeAllAnimations()
        maskLayer.path = UIBezierPath(rect: bounds).cgPath
        coverView.alpha = 1
        emitter.opacity = 1
        emitter.setActive(true)
    }

    @objc private func tap() {
        reveal()
    }
}

class HybridNitroSpoiler: HybridNitroSpoilerSpec {

    private let spoiler = NitroSpoilerView()

    var view: UIView {
        return spoiler
    }

    var revealed: Bool? {
        didSet {
            if revealed == true {
                spoiler.reveal()
            } else if revealed == false {
                spoiler.reset()
            }
        }
    }

    var coverColor: String? {
        didSet {
            if let c = coverColor {
                spoiler.cover = UIColor(hex: c)
            }
        }
    }

    var tintColor: String? {
        didSet {
            if let c = tintColor {
                spoiler.tint = UIColor(hex: c)
            }
        }
    }

    func reveal() throws {
        DispatchQueue.main.async {
            self.spoiler.reveal()
        }
        revealed = true
    }

    func reset() throws {
        DispatchQueue.main.async {
            self.spoiler.reset()
        }
        revealed = false
    }

    override init() {
        super.init()
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") {
            h.removeFirst()
        }

        if h.count == 3 {
            h = h.map {
                "\($0)\($0)"
            }
            .joined()
        }

        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)

        if h.count == 8 {
            self.init(
                red: CGFloat((rgb >> 24) & 0xFF) / 255,
                green: CGFloat((rgb >> 16) & 0xFF) / 255,
                blue: CGFloat((rgb >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgb & 0xFF) / 255
            )
        } else {
            self.init(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
}
