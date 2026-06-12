import UIKit

/// CAEmitterBehavior is a private CoreAnimation API; Telegram-iOS creates it
/// the same way (see UIKitUtils createEmitterBehavior).
enum EmitterBehavior {
    static func make(type: String) -> NSObject? {
        let selector = NSSelectorFromString(["behaviorWith", "Type:"].joined())
        guard let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined()) as? NSObject.Type,
              let method = behaviorClass.method(for: selector) else {
            return nil
        }
        let createBehavior = unsafeBitCast(method, to: (@convention(c) (Any?, Selector, Any?) -> NSObject).self)
        return createBehavior(behaviorClass, selector, type)
    }
}
