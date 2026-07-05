import Flutter
import UIKit
import WebKit
import AVFoundation
import CoreLocation

public class FixitWebviewPlugin: NSObject, FlutterPlugin, FixitWebViewHostApi {
    private var messenger: FlutterBinaryMessenger?
    private var locationManager: CLLocationManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = FixitWebviewPlugin()
        instance.messenger = messenger

        // ── Phase A: Memory Pressure Monitoring ──────────────────────────
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            FixitWebViewRegistry.broadcastEvent(type: "memoryPressure", value: "critical")
        }

        registrar.register(
            FixitWebViewFactory(messenger: messenger),
            withId: "com.fixit.fixit_webview/view"
        )

        FixitWebViewHostApiSetup.setUp(binaryMessenger: messenger, api: instance)

        let permissionChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/permissions",
            binaryMessenger: messenger
        )
        permissionChannel.setMethodCallHandler(instance.handleMethodCall)

        let uploadChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/upload",
            binaryMessenger: messenger
        )
        uploadChannel.setMethodCallHandler(instance.handleMethodCall)

        let downloadChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/download",
            binaryMessenger: messenger
        )
        downloadChannel.setMethodCallHandler(instance.handleMethodCall)

        let navigationChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/navigation",
            binaryMessenger: messenger
        )
        navigationChannel.setMethodCallHandler(instance.handleMethodCall)

        let offlineChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/offline",
            binaryMessenger: messenger
        )
        offlineChannel.setMethodCallHandler(instance.handleMethodCall)

        let lifecycleChannel = FlutterMethodChannel(
            name: "com.fixit.fixit_webview/lifecycle",
            binaryMessenger: messenger
        )
        lifecycleChannel.setMethodCallHandler(instance.handleMethodCall)
    }

    // MARK: - Method Channel Handler (Permissions + Upload + Download + Navigation + Offline)

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setCachedResponse":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let url = args["url"] as? String,
                  let data = args["data"] as? String else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            let mimeType = args["mimeType"] as? String ?? "text/html"
            FixitWebViewRegistry.get(viewId: viewId)?.setCachedResponse(url: url, data: data, mimeType: mimeType)
            result(true)
        case "clearOfflineCache":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.clearOfflineCache()
            result(true)
        case "setOfflineFallback":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let html = args["html"] as? String else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.setOfflineFallback(html: html)
            result(true)
        case "checkPermission":
            guard let type = (call.arguments as? [String: Any])?["type"] as? Int else {
                result(1)
                return
            }
            result(checkIosPermission(type: type).rawValue)
        case "requestPermission":
            guard let type = (call.arguments as? [String: Any])?["type"] as? Int else {
                result(1)
                return
            }
            requestIosPermission(type: type, completion: result)
        case "resolveUpload":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let requestId = args["requestId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            let filePaths = args["filePaths"] as? [String] ?? []
            FixitWebViewRegistry.get(viewId: viewId)?.resolveUpload(requestId: requestId, filePaths: filePaths)
            result(true)
        case "cancelUpload":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let requestId = args["requestId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.cancelUpload(requestId: requestId)
            result(true)
        case "startDownload":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let requestId = args["requestId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.startDownload(requestId: requestId)
            result(true)
        case "cancelDownload":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int,
                  let requestId = args["requestId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.cancelDownload(requestId: requestId)
            result(true)
        case "acceptSslError":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.acceptSslError()
            result(true)
        case "denySslError":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.denySslError()
            result(true)
        case "openDownloadedFile":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(false)
                return
            }
            let mimeType = args["mimeType"] as? String ?? ""
            let url = URL(fileURLWithPath: filePath)
            if #available(iOS 9.0, *) {
                let controller = UIDocumentInteractionController(url: url)
                // Present from the root view controller
                if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                    controller.presentPreview(animated: true)
                }
            }
            result(true)
        case "pauseWebView":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.pause()
            result(true)
        case "resumeWebView":
            guard let args = call.arguments as? [String: Any],
                  let viewIdInt = args["viewId"] as? Int else {
                result(false)
                return
            }
            let viewId = Int64(viewIdInt)
            FixitWebViewRegistry.get(viewId: viewId)?.resume()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private enum PermissionStatus: Int {
        case granted = 0
        case denied = 1
        case deniedForever = 2
        case restricted = 3
        case limited = 4
    }

    private func checkIosPermission(type: Int) -> PermissionStatus {
        switch type {
        case 0: // camera
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return mapAvStatus(status)
        case 1: // microphone
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return mapAvStatus(status)
        case 2: // location
            let status = CLLocationManager.authorizationStatus()
            return mapLocationStatus(status)
        default:
            return .denied
        }
    }

    private func requestIosPermission(type: Int, completion: @escaping FlutterResult) {
        switch type {
        case 0: // camera
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted ? PermissionStatus.granted.rawValue : PermissionStatus.denied.rawValue)
            }
        case 1: // microphone
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted ? PermissionStatus.granted.rawValue : PermissionStatus.denied.rawValue)
            }
        case 2: // location
            let manager = CLLocationManager()
            self.locationManager = manager
            manager.requestWhenInUseAuthorization()
            // Return current status immediately; delegate callback could be used for live updates
            let status = CLLocationManager.authorizationStatus()
            completion(mapLocationStatus(status).rawValue)
        default:
            completion(PermissionStatus.denied.rawValue)
        }
    }

    private func mapAvStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .denied
        @unknown default: return .denied
        }
    }

    private func mapLocationStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .denied
        @unknown default: return .denied
        }
    }

    // MARK: - FixitWebViewHostApi

    public func create(viewId: Int64, config: PigeonRuntimeConfig) throws {
        if let webView = FixitWebViewRegistry.get(viewId: viewId) {
            webView.applyConfig(config: config)
        } else {
            FixitWebViewRegistry.setPendingConfig(viewId: viewId, config: config)
        }
    }

    public func loadUrl(viewId: Int64, url: String) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.loadUrl(url: url)
    }

    public func loadUrlWithHeaders(viewId: Int64, url: String, headers: [String?: String?]?, method: String?, body: String?) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.loadUrlWithHeaders(url: url, headers: headers, method: method, body: body)
    }

    public func loadHtmlString(viewId: Int64, html: String, baseUrl: String?) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.loadHtmlString(html: html, baseUrl: baseUrl)
    }

    public func stopLoading(viewId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.stopLoading()
    }

    public func getTitle(viewId: Int64) throws -> String? {
        return FixitWebViewRegistry.get(viewId: viewId)?.getTitle()
    }

    public func goBack(viewId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.goBack()
    }

    public func goForward(viewId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.goForward()
    }

    public func reload(viewId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.reload()
    }

    public func clearCache(viewId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.clearCache()
    }

    public func clearCookies() throws {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                cookieStore.delete(cookie, completionHandler: nil)
            }
        }
    }

    public func setCookie(url: String, key: String, value: String) throws {
        if let nsUrl = URL(string: url),
           let cookie = HTTPCookie(properties: [
            .domain: nsUrl.host ?? "",
            .path: nsUrl.path,
            .name: key,
            .value: value,
            .secure: nsUrl.scheme == "https" ? "TRUE" : "FALSE"
           ]) {
            WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie, completionHandler: nil)
        }
    }

    public func getCookies(url: String, completion: @escaping (Result<[String?], Error>) -> Void) {
        guard let nsUrl = URL(string: url) else {
            completion(.success([]))
            return
        }
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        cookieStore.getAllCookies { cookies in
            let matching = cookies
                .filter { $0.domain == nsUrl.host || nsUrl.host?.hasSuffix($0.domain) == true }
                .map { "\($0.name)=\($0.value)" }
            completion(.success(matching))
        }
    }

    public func postBridgeMessage(viewId: Int64, message: String) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.postBridgeMessage(message: message)
    }

    public func httpAuthResponse(viewId: Int64, requestId: Int64, username: String, password: String) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.httpAuthResponse(requestId: Int(requestId), username: username, password: password)
    }

    public func cancelHttpAuth(viewId: Int64, requestId: Int64) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.cancelHttpAuth(requestId: Int(requestId))
    }

    public func updateSecurityConfig(viewId: Int64, mixedContentMode: Int64?, safeBrowsingEnabled: Bool?, zoomEnabled: Bool?) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.updateSecurityConfig(mixedContentMode: mixedContentMode, safeBrowsingEnabled: safeBrowsingEnabled, zoomEnabled: zoomEnabled)
    }

    public func evaluateJavascript(viewId: Int64, javascript: String) throws {
        FixitWebViewRegistry.get(viewId: viewId)?.evaluateJavascript(javascript: javascript)
    }

    public func runJavascriptReturningResult(viewId: Int64, javascript: String, completion: @escaping (Result<String?, Error>) -> Void) {
        if let view = FixitWebViewRegistry.get(viewId: viewId) {
            view.runJavascriptReturningResult(javascript: javascript, completion: completion)
        } else {
            completion(.failure(NSError(domain: "FixitWebviewPlugin", code: 404, userInfo: [NSLocalizedDescriptionKey: "WebView not found"])))
        }
    }

    public func dispose(viewId: Int64) throws {
        FixitWebViewRegistry.remove(viewId: viewId)?.dispose()
    }
}
