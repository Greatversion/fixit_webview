import Foundation
import WebKit

/// Thread‑safe singleton registry for FixitWebView instances on iOS.
/// The key is the viewId used by the Flutter side.
public final class FixitWebViewRegistry {
    private init() {}
    private static var storage: [Int64: FixitWebView] = [:]
    private static var pendingConfigs: [Int64: PigeonRuntimeConfig] = [:]
    private static let lock = NSLock()

    public static func register(viewId: Int64, view: FixitWebView) {
        lock.lock(); defer { lock.unlock() }
        storage[viewId] = view
        if let config = pendingConfigs.removeValue(forKey: viewId) {
            view.applyConfig(config: config)
        }
    }

    public static func get(viewId: Int64) -> FixitWebView? {
        lock.lock(); defer { lock.unlock() }
        return storage[viewId]
    }

    @discardableResult
    public static func remove(viewId: Int64) -> FixitWebView? {
        lock.lock(); defer { lock.unlock() }
        pendingConfigs.removeValue(forKey: viewId)
        return storage.removeValue(forKey: viewId)
    }

    public static func setPendingConfig(viewId: Int64, config: PigeonRuntimeConfig) {
        lock.lock(); defer { lock.unlock() }
        pendingConfigs[viewId] = config
    }

    public static func broadcastEvent(type: String, value: Any) {
        lock.lock(); defer { lock.unlock() }
        for (_, view) in storage {
            view.sendEvent(type: type, value: value)
        }
    }
}
