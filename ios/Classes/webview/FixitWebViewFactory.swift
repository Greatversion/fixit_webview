import Flutter
import UIKit

public class FixitWebViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let realId = params?["viewId"] as? Int64 ?? viewId
        let diagnosticsLevel = params?["diagnosticsLevel"] as? String
        
        // ── T1: PlatformView created ──────────────────────────────────────
        if let level = diagnosticsLevel, !level.isEmpty {
            FixitProfiler.shared.markT1PlatformViewCreated()
        }
        
        return FixitWebView(frame: frame, viewId: realId, messenger: messenger, diagnosticsLevel: diagnosticsLevel)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
