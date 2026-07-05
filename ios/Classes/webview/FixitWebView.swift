import Flutter
import UIKit
import WebKit
import AVFoundation
import Network

public class FixitWebView: NSObject, FlutterPlatformView, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKScriptMessageHandler, WKDownloadDelegate {
    private var webView: WKWebView
    private var viewId: Int64
    private var eventSink: FlutterEventSink?
    private var progressObserver: NSKeyValueObservation?
    private var titleObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var scrollObserver: NSKeyValueObservation?    private let diagnosticsLevel: String?
    private var diagnosticsEnabled: Bool { return diagnosticsLevel != nil && !diagnosticsLevel!.isEmpty }
    private var firstMeaningfulProgressMarked = false
    private var bridgeEnabled = false
    
    private var whitelist: [String] = []
    private var blacklist: [String] = []
    private var externalSchemes: [String] = ["tel", "mailto", "sms", "geo", "maps", "whatsapp", "tg"]
    private var pendingUploadHandlers: [Int: ([URL]?) -> Void] = [:]
    private var uploadRequestIdCounter = 0
    
    // Download tracking
    private var downloadRequestIdCounter = 0
    private var pendingDownloadHandlers: [Int: WKDownload] = [:]
    
    // WKDownloadDelegate progress tracking
    private var downloadProgressBytes: [Int: (received: Int64, total: Int64)] = [:]
    
    // SSL error pending decision
    private var pendingSslChallenge: (challenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)? = nil
    // HTTP auth pending decision
    private var pendingHttpAuth: (challenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)? = nil
    private var httpAuthRequestIdCounter = 0
    private var pendingHttpAuthRequestId: Int? = nil
    
    // Offline connectivity monitoring
    private var offlineEnabled = false
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.fixit.pathMonitor")
    
    // Offline cache
    private var offlineCache: [String: (data: String, mimeType: String)] = [:]
    private var offlineFallbackHtml: String = """
    <html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#121212;color:#e0e0e0"><div style="text-align:center"><h1>Offline</h1><p>This content is not available offline.</p></div></body></html>
    """
    
    // Scroll tracking
    private var lastScrollX: CGFloat = 0
    private var lastScrollY: CGFloat = 0

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, diagnosticsLevel: String? = nil) {
        self.viewId = viewId
        self.diagnosticsLevel = diagnosticsLevel
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        self.webView = WKWebView(frame: frame, configuration: configuration)
        super.init()
        
        // ── T2: Native WebView created ────────────────────────────────────
        if diagnosticsEnabled {
            FixitProfiler.shared.markT2NativeWebViewCreated()
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        let channelName = "com.fixit.fixit_webview/events_\(viewId)"
        let eventChannel = FlutterEventChannel(name: channelName, binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
        
        setupObservers()
        FixitWebViewRegistry.register(viewId: viewId, view: self)
    }

    public func view() -> UIView {
        return webView
    }

    // MARK: - Observers

    private func setupObservers() {
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, change in
            guard let self = self, let progress = change.newValue else { return }
            self.sendEvent(type: "progress", value: progress)
            
            if self.diagnosticsEnabled && !self.firstMeaningfulProgressMarked && progress >= 0.10 {
                self.firstMeaningfulProgressMarked = true
                FixitProfiler.shared.markT4FirstMeaningfulProgress()
            }
        }

        titleObserver = webView.observe(\.title, options: .new) { [weak self] webView, change in
            guard let self = self else { return }
            if let title = change.newValue as? String {
                self.sendEvent(type: "title", value: title)
            }
        }

        urlObserver = webView.observe(\.url, options: .new) { [weak self] webView, change in
            guard let self = self else { return }
            if let url = change.newValue as? URL {
                self.sendEvent(type: "url", value: url.absoluteString)
            }
        }

        // Scroll observer via the underlying UIScrollView
        webView.scrollView.delegate = self
    }

    // MARK: - Config

    func applyConfig(config: PigeonRuntimeConfig) {
        whitelist = config.navigationWhitelist.compactMap { $0 }
        blacklist = config.navigationBlacklist.compactMap { $0 }
        externalSchemes = config.externalSchemes.compactMap { $0 }
        bridgeEnabled = config.enableBridge
        offlineEnabled = config.enableOffline
        
        // Setup connectivity monitoring when offline enabled
        if offlineEnabled {
            let monitor = NWPathMonitor()
            self.pathMonitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                let state = path.status == .satisfied ? "online" : "offline"
                self?.sendEvent(type: "connectivityChanged", value: state)
            }
            monitor.start(queue: pathMonitorQueue)
        }
        
        // Third-party cookies: iOS WKWebView uses ITP which cannot be fully disabled
        // via public API. This flag applies to HTTPCookieStorage.shared for non-WebKit requests.
        if config.acceptThirdPartyCookies {
            HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let userAgent = config.userAgent {
                self.webView.customUserAgent = userAgent
            }
            
            self.webView.configuration.preferences.javaScriptEnabled = config.javaScriptEnabled
            self.webView.configuration.mediaTypesRequiringUserActionForPlayback = 
                config.mediaPlaybackRequiresGesture ? .all : []
            
            if self.bridgeEnabled {
                self.webView.configuration.userContentController.add(self, name: "fixitBridge")
            }
            
            if config.initialUrl.count > 0 && config.initialUrl != "about:blank" {
                self.loadUrl(url: config.initialUrl)
            }
        }
    }

    // ── Bridge Methods ──────────────────────────────────────────────────

    func postBridgeMessage(message: String) {
        guard bridgeEnabled else { return }
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "window.dispatchEvent(new CustomEvent('fixit-bridge', {detail: '\(escaped)'}))"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "fixitBridge" else { return }
        let body = message.body
        let value: String
        if let str = body as? String {
            value = str
        } else if let data = try? JSONSerialization.data(withJSONObject: body, options: []),
                  let str = String(data: data, encoding: .utf8) {
            value = str
        } else {
            value = "\(body)"
        }
        let event: [String: Any] = ["type": "bridgeMessage", "value": value]
        eventSink?(event)
    }

    // MARK: - Event Helpers

    func sendEvent(type: String, value: Any) {
        let event: [String: Any] = ["type": type, "value": value]
        eventSink?(event)
    }

    private func sendNavigationState() {
        let event: [String: Any] = [
            "type": "navigationState",
            "canGoBack": webView.canGoBack,
            "canGoForward": webView.canGoForward
        ]
        eventSink?(event)
    }

    private func sendDiagnosticsEvent(name: String, data: [String: Any]) {
        var event: [String: Any] = ["type": "diagnostics", "name": name]
        for (k, v) in data { event[k] = v }
        eventSink?(event)
    }

    // MARK: - WKNavigationDelegate

    // MARK: - Lifecycle Persistence

    func pause() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // WKWebView doesn't expose pause/resume, so we bridge to JS
            let js = "window.dispatchEvent(new CustomEvent('fixit-lifecycle', {detail: 'pause'}))"
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func resume() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let js = "window.dispatchEvent(new CustomEvent('fixit-lifecycle', {detail: 'resume'}))"
            self.webView.evaluateJavaScript(js, completionHandler: nil)
            // Restore focus
            self.webView.evaluateJavaScript("window.focus()", completionHandler: nil)
        }
    }

    // MARK: - Renderer Crash Recovery

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let event: [String: Any] = [
            "type": "rendererCrashed",
            "description": "WKWebView process terminated",
            "rendererDropped": true
        ]
        eventSink?(event)
    }

    func recreateWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let lastUrl = self.webView.url?.absoluteString ?? ""
            if !lastUrl.isEmpty && lastUrl != "about:blank" {
                self.webView.load(URLRequest(url: URL(string: lastUrl)!))
            } else {
                self.webView.reload()
            }
            let restartEvent: [String: Any] = ["type": "rendererRestarted"]
            self.eventSink?(restartEvent)
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if diagnosticsEnabled {
            FixitProfiler.shared.markT3FirstFrame()
        }
        sendEvent(type: "loading", value: true)
        if let url = webView.url?.absoluteString {
            sendEvent(type: "url", value: url)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if diagnosticsEnabled {
            FixitProfiler.shared.markT5PageFinished()
            sendDiagnosticsEvent(name: "startupTimeline", data: [
                "timeline": FixitProfiler.shared.buildTimeline(),
                "milestones": FixitProfiler.shared.snapshotAsMap()
            ])
        }
        sendEvent(type: "loading", value: false)
        if let url = webView.url?.absoluteString {
            sendEvent(type: "url", value: url)
        }
        sendNavigationState()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        sendEvent(type: "loading", value: false)
        sendEvent(type: "error", value: error.localizedDescription)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        sendEvent(type: "loading", value: false)
        sendEvent(type: "error", value: error.localizedDescription)
    }

    // Download detection: when WKWebView encounters a download it can't render
    @available(iOS 14.5, *)
    public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        let requestId = downloadRequestIdCounter
        downloadRequestIdCounter += 1
        pendingDownloadHandlers[requestId] = download
        download.delegate = self
        
        let totalBytes = navigationResponse.response.expectedContentLength
        downloadProgressBytes[requestId] = (0, totalBytes)
        
        let event: [String: Any] = [
            "type": "downloadRequested",
            "requestId": requestId,
            "url": navigationResponse.response.url?.absoluteString ?? "",
            "mimeType": navigationResponse.response.mimeType ?? "",
            "contentLength": totalBytes
        ]
        eventSink?(event)
    }

    // For non-renderable content, decide to download
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType {
            let requestId = downloadRequestIdCounter
            downloadRequestIdCounter += 1
            let totalBytes = navigationResponse.response.expectedContentLength
            downloadProgressBytes[requestId] = (0, totalBytes)
            
            let event: [String: Any] = [
                "type": "downloadRequested",
                "requestId": requestId,
                "url": navigationResponse.response.url?.absoluteString ?? "",
                "mimeType": navigationResponse.response.mimeType ?? "",
                "contentLength": totalBytes
            ]
            eventSink?(event)
            if #available(iOS 14.5, *) {
                decisionHandler(.download)
            } else {
                decisionHandler(.cancel)
            }
            return
        }
        decisionHandler(.allow)
    }
    
    // MARK: - WKDownloadDelegate
    
    @available(iOS 14.5, *)
    public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // Find the requestId for this download
        if let pair = pendingDownloadHandlers.first(where: { $0.value === download }) {
            let requestId = pair.key
            let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let destination = dir.appendingPathComponent(suggestedFilename)
            downloadProgressBytes[requestId] = (0, response.expectedContentLength)
            completionHandler(destination)
        } else {
            let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            completionHandler(dir.appendingPathComponent(suggestedFilename))
        }
    }
    
    @available(iOS 14.5, *)
    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let pair = pendingDownloadHandlers.first(where: { $0.value === download }) {
            let requestId = pair.key
            pendingDownloadHandlers.removeValue(forKey: requestId)
            downloadProgressBytes.removeValue(forKey: requestId)
            let event: [String: Any] = [
                "type": "downloadFailed",
                "requestId": requestId,
                "error": error.localizedDescription
            ]
            eventSink?(event)
        }
    }
    
    @available(iOS 14.5, *)
    public func downloadDidFinish(_ download: WKDownload) {
        if let pair = pendingDownloadHandlers.first(where: { $0.value === download }) {
            let requestId = pair.key
            pendingDownloadHandlers.removeValue(forKey: requestId)
            downloadProgressBytes.removeValue(forKey: requestId)
            let event: [String: Any] = [
                "type": "downloadCompleted",
                "requestId": requestId,
                "filePath": "" // WKDownload does not provide the final path; user can find it in Downloads
            ]
            eventSink?(event)
        }
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let urlString = url.absoluteString
        let scheme = url.scheme ?? ""

        // 0. Offline cache check: if cached, serve cached HTML
        if offlineEnabled, let cached = offlineCache[urlString] {
            sendEvent(type: "loading", value: true)
            DispatchQueue.main.async { [weak self] in
                self?.webView.loadHTMLString(cached.data, baseURL: url)
            }
            sendEvent(type: "loading", value: false)
            decisionHandler(.cancel)
            return
        }

        // 1. Blacklist
        if blacklist.contains(where: { urlString.contains($0) }) {
            let event: [String: Any] = [
                "type": "navigationRequested",
                "url": urlString,
                "isMainFrame": navigationAction.targetFrame?.isMainFrame ?? true,
                "isRedirect": navigationAction.navigationType == .redirect,
                "navigationType": "blocked"
            ]
            eventSink?(event)
            sendEvent(type: "error", value: "Navigation blocked by blacklist: \(urlString)")
            decisionHandler(.cancel)
            return
        }

        // 2. Whitelist
        if !whitelist.isEmpty && !whitelist.contains(where: { urlString.contains($0) }) {
            let event: [String: Any] = [
                "type": "navigationRequested",
                "url": urlString,
                "isMainFrame": navigationAction.targetFrame?.isMainFrame ?? true,
                "isRedirect": navigationAction.navigationType == .redirect,
                "navigationType": "blocked"
            ]
            eventSink?(event)
            sendEvent(type: "error", value: "Navigation blocked by whitelist: \(urlString)")
            decisionHandler(.cancel)
            return
        }

        // 3. External schemes → open in OS
        if externalSchemes.contains(scheme) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            let event: [String: Any] = [
                "type": "navigationRequested",
                "url": urlString,
                "isMainFrame": navigationAction.targetFrame?.isMainFrame ?? true,
                "isRedirect": navigationAction.navigationType == .redirect,
                "navigationType": "external"
            ]
            eventSink?(event)
            decisionHandler(.cancel)
            return
        }

        // 4. Emit navigation event and allow
        let navType: String
        switch navigationAction.navigationType {
        case .linkActivated: navType = "link"
        case .formSubmitted: navType = "form"
        case .backForward: navType = "backForward"
        case .reload: navType = "reload"
        case .redirect: navType = "redirect"
        default: navType = "other"
        }
        let event: [String: Any] = [
            "type": "navigationRequested",
            "url": urlString,
            "isMainFrame": navigationAction.targetFrame?.isMainFrame ?? true,
            "isRedirect": navigationAction.navigationType == .redirect,
            "navigationType": navType
        ]
        eventSink?(event)
        decisionHandler(.allow)
    }

    public func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Save for Dart-side decision
            pendingSslChallenge = (challenge, completionHandler)
            let event: [String: Any] = [
                "type": "sslError",
                "url": webView.url?.absoluteString ?? "",
                "message": "SSL certificate validation failed for \(challenge.protectionSpace.host)",
                "host": challenge.protectionSpace.host
            ]
            eventSink?(event)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                  challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
            httpAuthRequestIdCounter += 1
            let requestId = httpAuthRequestIdCounter
            pendingHttpAuthRequestId = requestId
            pendingHttpAuth = (challenge, completionHandler)
            let event: [String: Any] = [
                "type": "httpAuthRequested",
                "host": challenge.protectionSpace.host,
                "realm": challenge.protectionSpace.realm ?? "",
                "port": challenge.protectionSpace.port,
                "requestId": requestId
            ]
            eventSink?(event)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func acceptSslError() {
        guard let pending = pendingSslChallenge else { return }
        pendingSslChallenge = nil
        if let serverTrust = pending.challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            pending.completionHandler(.useCredential, credential)
        } else {
            pending.completionHandler(.performDefaultHandling, nil)
        }
    }

    func denySslError() {
        guard let pending = pendingSslChallenge else { return }
        pendingSslChallenge = nil
        pending.completionHandler(.cancelAuthenticationChallenge, nil)
    }

    // MARK: - WKUIDelegate (target="_blank" / window.open)

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // target="_blank" or window.open() → open externally
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return nil
    }

    // Media permission (Phase 5 — check actual iOS permission status)
    #if compiler(>=5.8)
    @available(iOS 15.0, *)
    public func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let avType: AVMediaType
        switch type {
        case .camera: avType = .video
        case .microphone: avType = .audio
        @unknown default:
            decisionHandler(.deny)
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: avType)
        switch status {
        case .authorized:
            decisionHandler(.grant)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: avType) { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        default:
            decisionHandler(.deny)
        }
    }
    #endif

    /// WKUIDelegate: file upload panel
    public func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let requestId = uploadRequestIdCounter
        uploadRequestIdCounter += 1
        pendingUploadHandlers[requestId] = completionHandler
        let event: [String: Any] = [
            "type": "uploadRequested",
            "requestId": requestId,
            "acceptTypes": parameters.acceptMIMETypes,
            "allowsMultipleSelection": parameters.allowsMultipleSelection,
        ]
        eventSink?(event)
    }

    func resolveUpload(requestId: Int, filePaths: [String]) {
        guard let handler = pendingUploadHandlers.removeValue(forKey: requestId) else { return }
        let urls = filePaths.compactMap { URL(string: $0) }
        DispatchQueue.main.async { handler(urls) }
    }

    func cancelUpload(requestId: Int) {
        guard let handler = pendingUploadHandlers.removeValue(forKey: requestId) else { return }
        DispatchQueue.main.async { handler(nil) }
    }

    // MARK: - Download Methods

    func startDownload(requestId: Int) {
        // Downloads are handled automatically via WKDownloadDelegate.
        // If the download was initiated via the download listener (pre-iOS 14.5),
        // this is a no-op. For iOS 14.5+, the delegate callbacks handle everything.
        // This method exists to match the API pattern — the actual download
        // is already in progress from decidePolicyFor navigationResponse.
    }

    func cancelDownload(requestId: Int) {
        if #available(iOS 14.5, *) {
            if let download = pendingDownloadHandlers.removeValue(forKey: requestId) {
                download.cancel { [weak self] _ in
                    self?.downloadProgressBytes.removeValue(forKey: requestId)
                }
            }
        }
        downloadProgressBytes.removeValue(forKey: requestId)
    }

    // MARK: - Offline Cache API

    func setCachedResponse(url: String, data: String, mimeType: String) {
        offlineCache[url] = (data, mimeType)
    }

    func clearOfflineCache() {
        offlineCache.removeAll()
    }

    func setOfflineFallback(html: String) {
        offlineFallbackHtml = html
    }

    // MARK: - UIScrollViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let x = scrollView.contentOffset.x
        let y = scrollView.contentOffset.y
        let dx = x - lastScrollX
        let dy = y - lastScrollY
        lastScrollX = x
        lastScrollY = y

        let event: [String: Any] = [
            "type": "scroll",
            "x": Int(x),
            "y": Int(y),
            "dx": Int(dx),
            "dy": Int(dy),
        ]
        eventSink?(event)
    }

    // MARK: - PlatformView

    override public var description: String { return "FixitWebView(\(viewId))" }

    public func dispose() {
        pathMonitor?.cancel()
        pathMonitor = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.progressObserver?.invalidate()
            self.progressObserver = nil
            self.titleObserver?.invalidate()
            self.titleObserver = nil
            self.urlObserver?.invalidate()
            self.urlObserver = nil
            self.scrollObserver?.invalidate()
            self.scrollObserver = nil
            self.webView.scrollView.delegate = nil
            if self.bridgeEnabled {
                self.webView.configuration.userContentController.removeScriptMessageHandler(forName: "fixitBridge")
            }
            self.eventSink = nil
        }
        FixitWebViewRegistry.remove(viewId: viewId)
        if diagnosticsEnabled { FixitProfiler.shared.reset() }
    }

    // MARK: - Public Navigation API

    func loadUrl(url: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let nsUrl = URL(string: url) {
                let request = URLRequest(url: nsUrl)
                self.webView.load(request)
            }
        }
    }

    func loadHtmlString(html: String, baseUrl: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let base = baseUrl != nil ? URL(string: baseUrl!) : nil
            self.webView.loadHTMLString(html, baseURL: base)
        }
    }

    func stopLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.webView.stopLoading()
        }
    }

    func getTitle() -> String? {
        return webView.title
    }

    func goBack() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.webView.canGoBack {
                self.webView.goBack()
            }
        }
    }

    func goForward() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.webView.canGoForward {
                self.webView.goForward()
            }
        }
    }

    func reload() {
        DispatchQueue.main.async { [weak self] in
            self?.webView.reload()
        }
    }

    func clearCache() {
        DispatchQueue.main.async {
            let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
            let date = Date(timeIntervalSince1970: 0)
            WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date) {}
        }
    }

    func evaluateJavascript(javascript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(javascript, completionHandler: nil)
        }
    }

    // ── Phase 7: Custom Headers / POST ─────────────────────────────────────

    func loadUrlWithHeaders(url: String, headers: [String?: String?]?, method: String?, body: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let nsUrl = URL(string: url) else { return }
            var request = URLRequest(url: nsUrl)
            if let method = method, method.uppercased() == "POST", let body = body {
                request.httpMethod = "POST"
                request.httpBody = body.data(using: .utf8)
            }
            if let headers = headers {
                for (key, value) in headers {
                    if let k = key, let v = value {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                }
            }
            self.webView.load(request)
        }
    }

    // ── Phase 7: HTTP Auth Response ────────────────────────────────────────

    func httpAuthResponse(requestId: Int, username: String, password: String) {
        guard requestId == pendingHttpAuthRequestId, let pending = pendingHttpAuth else { return }
        pendingHttpAuth = nil
        pendingHttpAuthRequestId = nil
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        pending.completionHandler(.useCredential, credential)
    }

    func cancelHttpAuth(requestId: Int) {
        guard requestId == pendingHttpAuthRequestId, let pending = pendingHttpAuth else { return }
        pendingHttpAuth = nil
        pendingHttpAuthRequestId = nil
        pending.completionHandler(.rejectProtectionSpace, nil)
    }

    // ── Phase 7: Update Security Config ────────────────────────────────────

    func updateSecurityConfig(mixedContentMode: Int64?, safeBrowsingEnabled: Bool?, zoomEnabled: Bool?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let enabled = zoomEnabled {
                self.webView.scrollView.pinchGestureRecognizer?.isEnabled = enabled
                self.webView.scrollView.isScrollEnabled = enabled
            }
            // WKWebView has no direct mixed content API; safe browsing is always on
        }
    }

    func runJavascriptReturningResult(javascript: String, completion: @escaping (Result<String?, Error>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(javascript) { result, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let stringResult = result.map { "\($0)" }
                    completion(.success(stringResult))
                }
            }
        }
    }
}

extension FixitWebView: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        sendNavigationState()
        
        if diagnosticsEnabled {
            sendDiagnosticsEvent(name: "nativeReady", data: ["viewId": viewId])
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
