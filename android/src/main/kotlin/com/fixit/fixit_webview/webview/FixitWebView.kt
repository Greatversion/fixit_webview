package com.fixit.fixit_webview.webview

import android.Manifest
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.database.ContentObserver
import android.database.Cursor
import android.graphics.Bitmap
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.provider.OpenableColumns
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.net.http.SslError
import android.webkit.SslErrorHandler
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import java.util.HashMap
import java.util.concurrent.ConcurrentHashMap

class FixitWebView(
    private val context: Context,
    val viewId: Int,
    messenger: BinaryMessenger,
    internal val diagnosticsLevel: String? = null,
) : PlatformView {

    internal val diagnosticsEnabled: Boolean = !diagnosticsLevel.isNullOrEmpty()

    private val webView: WebView = WebView(context)
    private var eventSink: EventChannel.EventSink? = null
    private var firstPaintMarked = false
    private var bridgeEnabled = false
    private var offlineEnabled = false
    private var connectivityCallbackRegistered = false
    private val connectivityCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            sendEvent("connectivityChanged", "online")
        }
        override fun onLost(network: Network) {
            sendEvent("connectivityChanged", "offline")
        }
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                sendEvent("connectivityChanged", "online")
            } else {
                sendEvent("connectivityChanged", "offline")
            }
        }
    }
    private val pendingUploadCallbacks = HashMap<Int, ValueCallback<Array<Uri>>>()
    private var uploadRequestIdCounter = 0
    private var downloadRequestIdCounter = 0
    private val pendingDownloadUrls = HashMap<Int, DownloadMeta>() // requestId -> metadata
    private val pendingDownloads = HashMap<Int, Long>() // requestId -> downloadManagerId
    
    private data class DownloadMeta(
        val url: String,
        val mimeType: String,
        val contentDisposition: String,
    )
    private var downloadReceiverRegistered = false
    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
                val dmId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                val entry = pendingDownloads.entries.find { it.value == dmId }
                if (entry != null) {
                    val requestId = entry.key
                    pendingDownloads.remove(requestId)
                    val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    val query = DownloadManager.Query().setFilterById(dmId)
                    val cursor = dm.query(query)
                    if (cursor != null && cursor.moveToFirst()) {
                        val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            val uri = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                            sendEvent("downloadCompleted", mapOf(
                                "requestId" to requestId,
                                "filePath" to (uri ?: "")
                            ))
                        } else {
                            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                            sendEvent("downloadFailed", mapOf(
                                "requestId" to requestId,
                                "error" to "Download failed: $reason"
                            ))
                        }
                        cursor.close()
                    }
                }
            }
        }
    }

    // ── JS Bridge Interface ────────────────────────────────────────────────
    private val bridgeInterface = object {
        @JavascriptInterface
        fun postMessage(message: String) {
            Handler(Looper.getMainLooper()).post {
                val event = HashMap<String, Any>()
                event["type"] = "bridgeMessage"
                event["value"] = message
                eventSink?.success(event)
            }
        }
    }
    
    private var whitelist: List<String> = emptyList()
    private var blacklist: List<String> = emptyList()
    private var externalSchemes: List<String> = emptyList()
    private var pendingSslHandler: SslErrorHandler? = null
    private var pendingSslError: String? = null
    private var pendingHttpAuthHandler: android.webkit.HttpAuthHandler? = null
    private var pendingHttpAuthHost: String? = null
    private var pendingHttpAuthRealm: String? = null
    private var pendingHttpAuthRequestId: Int = 0
    private var httpAuthRequestIdCounter: Int = 0

    // ── Offline cache ──────────────────────────────────────────────────────────
    private data class CacheEntry(val data: String, val mimeType: String)
    private val offlineCache = ConcurrentHashMap<String, CacheEntry>()
    private var offlineFallbackHtml: String =
        "<html><body style=\"display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#121212;color:#e0e0e0\"><div style=\"text-align:center\"><h1>Offline</h1><p>This content is not available offline.</p></div></body></html>"

    init {
        if (diagnosticsEnabled) FixitProfiler.markT2NativeWebViewCreated()

        FixitWebViewRegistry.register(viewId, this)

        val channelName = "com.fixit.fixit_webview/events_$viewId"
        EventChannel(messenger, channelName).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                sendNavigationState()

                if (diagnosticsEnabled) {
                    sendDiagnosticsEvent("nativeReady", mapOf("viewId" to viewId))
                }
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        setupWebView()
        setupDownloadListener()
        setupScrollListener()
    }

    private fun setupWebView() {
        // We will apply final settings when applyConfig is called,
        // but we set some safe base defaults here.
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.setSupportMultipleWindows(true)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                if (diagnosticsEnabled) FixitProfiler.markT3FirstFrame()
                sendEvent("loading", true)
                url?.let { sendEvent("url", it) }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (diagnosticsEnabled) {
                    FixitProfiler.markT5PageFinished()
                    sendDiagnosticsEvent(
                        "startupTimeline",
                        mapOf(
                            "timeline"  to FixitProfiler.buildTimeline(),
                            "milestones" to FixitProfiler.snapshotAsLongMap(),
                        )
                    )
                }
                sendEvent("loading", false)
                url?.let { sendEvent("url", it) }
                sendNavigationState()
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false
                val scheme = Uri.parse(url).scheme ?: ""

                // 1. Blacklist
                if (blacklist.any { url.contains(it) }) {
                    val event = HashMap<String, Any>()
                    event["type"] = "navigationRequested"
                    event["url"] = url
                    event["isMainFrame"] = request?.isForMainFrame ?: true
                    event["isRedirect"] = request?.isRedirect ?: false
                    event["navigationType"] = "blocked"
                    eventSink?.success(event)
                    sendEvent("error", "Navigation blocked by blacklist: $url")
                    return true
                }

                // 2. Whitelist (if not empty, url MUST match)
                if (whitelist.isNotEmpty() && !whitelist.any { url.contains(it) }) {
                    val event = HashMap<String, Any>()
                    event["type"] = "navigationRequested"
                    event["url"] = url
                    event["isMainFrame"] = request?.isForMainFrame ?: true
                    event["isRedirect"] = request?.isRedirect ?: false
                    event["navigationType"] = "blocked"
                    eventSink?.success(event)
                    sendEvent("error", "Navigation blocked by whitelist: $url")
                    return true
                }

                // 3. External schemes (from config + hardcoded defaults)
                if (externalSchemes.contains(scheme) ||
                    scheme in listOf("tel", "mailto", "sms", "geo", "maps", "whatsapp", "tg", "intent")) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        context.startActivity(intent)
                        val event = HashMap<String, Any>()
                        event["type"] = "navigationRequested"
                        event["url"] = url
                        event["isMainFrame"] = request?.isForMainFrame ?: true
                        event["isRedirect"] = request?.isRedirect ?: false
                        event["navigationType"] = "external"
                        eventSink?.success(event)
                        return true
                    } catch (e: Exception) {
                        sendEvent("error", "Failed to launch external scheme: $url")
                    }
                }

                // 4. Emit navigation event and allow
                val event = HashMap<String, Any>()
                event["type"] = "navigationRequested"
                event["url"] = url
                event["isMainFrame"] = request?.isForMainFrame ?: true
                event["isRedirect"] = request?.isRedirect ?: false
                event["navigationType"] = if (request?.isRedirect == true) "redirect" else "link"
                eventSink?.success(event)

                return false // Let WebView load it
            }

            override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                val url = request?.url?.toString() ?: return null
                val entry = offlineCache[url]
                if (entry != null) {
                    return WebResourceResponse(entry.mimeType, "UTF-8", java.io.ByteArrayInputStream(entry.data.toByteArray()))
                }
                // Check connectivity: if offline, serve fallback for main-frame requests
                if (request?.isForMainFrame == true) {
                    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val activeNetwork = cm.activeNetwork
                    val caps = cm.getNetworkCapabilities(activeNetwork)
                    val isOnline = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                    if (!isOnline) {
                        return WebResourceResponse("text/html", "UTF-8",
                            java.io.ByteArrayInputStream(offlineFallbackHtml.toByteArray()))
                    }
                }
                return null
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    sendEvent("error", error?.description?.toString() ?: "Unknown error")
                }
            }

            override fun onReceivedHttpError(view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?) {
                super.onReceivedHttpError(view, request, errorResponse)
                if (request?.isForMainFrame == true) {
                    sendEvent("httpError", "HTTP ${errorResponse?.statusCode}: ${errorResponse?.reasonPhrase}")
                }
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                pendingSslHandler = handler
                pendingSslError = error?.toString()
                val event = HashMap<String, Any>()
                event["type"] = "sslError"
                event["url"] = view?.url ?: ""
                event["message"] = error?.toString() ?: "SSL Error"
                event["host"] = Uri.parse(view?.url ?: "").host ?: ""
                eventSink?.success(event)
            }

            override fun onReceivedHttpAuthRequest(view: WebView?, handler: android.webkit.HttpAuthHandler?, host: String?, realm: String?) {
                pendingHttpAuthHandler = handler
                pendingHttpAuthHost = host
                pendingHttpAuthRealm = realm
                pendingHttpAuthRequestId = ++httpAuthRequestIdCounter
                val event = HashMap<String, Any>()
                event["type"] = "httpAuthRequested"
                event["host"] = host ?: ""
                event["realm"] = realm ?: ""
                event["port"] = Uri.parse(view?.url ?: "").port
                event["requestId"] = pendingHttpAuthRequestId
                eventSink?.success(event)
            }

            // ── Phase A: Renderer Crash Recovery ──────────────────────────────
            override fun onRenderProcessGone(view: WebView?, detail: android.webkit.RenderProcessGoneDetail?): Boolean {
                val event = HashMap<String, Any>()
                event["type"] = "rendererCrashed"
                event["description"] = detail?.toString() ?: "Render process gone"
                event["rendererDropped"] = detail?.didCrash() ?: true
                eventSink?.success(event)
                // Return true to handle the crash (don't kill the app)
                return true
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                sendEvent("progress", newProgress.toDouble() / 100.0)

                if (diagnosticsEnabled && !firstPaintMarked && newProgress >= 10) {
                    firstPaintMarked = true
                    FixitProfiler.markT4FirstMeaningfulProgress()
                }
            }

            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                title?.let { sendEvent("title", it) }
            }

            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                consoleMessage?.let {
                    sendEvent("consoleMessage", it.message())
                }
                return super.onConsoleMessage(consoleMessage)
            }

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                // Intercept target="_blank" / window.open()
                val transport = resultMsg?.obj as? WebView.WebViewTransport
                if (transport != null) {
                    // To handle this properly without a new WebView, we ask the WebView for the URL
                    // Unfortunately Android doesn't expose the URL easily here without creating a dummy WebView.
                    // For now, we will let it fail or open externally if we intercept the next shouldOverrideUrlLoading.
                    // The simplest reliable way on Android to open externally is to create a dummy webview,
                    // intercept the load, and throw an Intent.
                    val dummyWebView = WebView(view!!.context)
                    dummyWebView.webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(v: WebView?, request: WebResourceRequest?): Boolean {
                            val url = request?.url?.toString() ?: return false
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            context.startActivity(intent)
                            return true
                        }
                    }
                    transport.webView = dummyWebView
                    resultMsg.sendToTarget()
                    return true
                }
                return false
            }

            // ── WebRTC / Media Permission Request (Phase 5) ──────────────
            override fun onPermissionRequest(request: android.webkit.PermissionRequest?) {
                if (request == null) return
                val ctx = webView?.context ?: return
                val grantedResources = mutableListOf<String>()
                val deniedResources = mutableListOf<String>()

                for (resource in request.resources) {
                    val permission = when (resource) {
                        android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE -> Manifest.permission.CAMERA
                        android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE -> Manifest.permission.RECORD_AUDIO
                        else -> null
                    }
                    if (permission != null && ContextCompat.checkSelfPermission(ctx, permission) == PackageManager.PERMISSION_GRANTED) {
                        grantedResources.add(resource)
                    } else {
                        deniedResources.add(resource)
                    }
                }

                if (deniedResources.isEmpty()) {
                    request.grant(grantedResources.toTypedArray())
                } else {
                    request.deny()
                }
            }

            // ── File Chooser (Phase 3 Upload Engine) ──────────────────────
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                if (filePathCallback == null) return false
                val requestId = ++uploadRequestIdCounter
                pendingUploadCallbacks[requestId] = filePathCallback
                sendEvent("uploadRequested", mapOf(
                    "requestId" to requestId,
                    "acceptTypes" to (fileChooserParams?.acceptTypes?.toList() ?: emptyList<String>()),
                    "isCaptureEnabled" to (fileChooserParams?.isCaptureEnabled ?: false)
                ))
                return true
            }
        }
    }

    // ── Download Listener ──────────────────────────────────────────────────

    private fun setupDownloadListener() {
        webView.setDownloadListener(DownloadListener { url, userAgent, contentDisposition, mimeType, contentLength ->
            val requestId = ++downloadRequestIdCounter
            pendingDownloadUrls[requestId] = DownloadMeta(url, mimeType ?: "", contentDisposition ?: "")
            val event = HashMap<String, Any>()
            event["type"] = "downloadRequested"
            event["requestId"] = requestId
            event["url"] = url
            event["userAgent"] = userAgent ?: ""
            event["contentDisposition"] = contentDisposition ?: ""
            event["mimeType"] = mimeType ?: ""
            event["contentLength"] = contentLength
            eventSink?.success(event)
        })
    }

    // ── Scroll Listener ───────────────────────────────────────────────────

    private fun setupScrollListener() {
        webView.setOnScrollChangeListener { _, scrollX, scrollY, oldScrollX, oldScrollY ->
            val event = HashMap<String, Any>()
            event["type"] = "scroll"
            event["x"] = scrollX
            event["y"] = scrollY
            event["dx"] = scrollX - oldScrollX
            event["dy"] = scrollY - oldScrollY
            eventSink?.success(event)
        }
    }
    
    fun applyConfig(config: PigeonRuntimeConfig) {
        whitelist = config.navigationWhitelist.filterNotNull()
        blacklist = config.navigationBlacklist.filterNotNull()
        externalSchemes = config.externalSchemes.filterNotNull()
        bridgeEnabled = config.enableBridge
        val wasOfflineEnabled = offlineEnabled
        offlineEnabled = config.enableOffline
        
        webView.post {
            // Setup connectivity monitoring when offline enabled
            if (offlineEnabled && !wasOfflineEnabled) {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()
                cm.registerNetworkCallback(request, connectivityCallback)
                connectivityCallbackRegistered = true
                
                // Send initial state
                val activeNetwork = cm.activeNetwork
                val caps = cm.getNetworkCapabilities(activeNetwork)
                val isOnline = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                sendEvent("connectivityChanged", if (isOnline) "online" else "offline")
            }
            webView.settings.apply {
                javaScriptEnabled = config.javaScriptEnabled
                domStorageEnabled = config.domStorageEnabled
                allowFileAccess = config.allowFileAccess
                allowContentAccess = config.allowContentAccess
                mediaPlaybackRequiresUserGesture = config.mediaPlaybackRequiresGesture
                
                if (config.userAgent != null) {
                    userAgentString = config.userAgent
                }
                
                if (!config.enableCache) {
                    cacheMode = WebSettings.LOAD_NO_CACHE
                }
            }

            // Third-party cookies
            CookieManager.getInstance().setAcceptThirdPartyCookies(webView, config.acceptThirdPartyCookies)

            if (bridgeEnabled) {
                webView.addJavascriptInterface(bridgeInterface, "FixitBridge")
            }
            
            if (config.initialUrl.isNotEmpty() && config.initialUrl != "about:blank") {
                webView.loadUrl(config.initialUrl)
            }
        }
    }

    fun startDownload(requestId: Int, destinationDir: String?) {
        val meta = pendingDownloadUrls[requestId] ?: return
        if (!downloadReceiverRegistered) {
            downloadReceiverRegistered = true
            context.registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                Context.RECEIVER_EXPORTED)
        }

        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val uri = Uri.parse(meta.url)
        val cd = meta.contentDisposition
        val fileName = if (cd.isNotEmpty()) {
            val parts = cd.split(";")
            parts.find { it.trim().startsWith("filename=") }?.trim()?.removePrefix("filename=")?.removeSurrounding("\"") ?: uri.lastPathSegment ?: "download_$requestId"
        } else {
            uri.lastPathSegment ?: "download_$requestId"
        }

        val dir = destinationDir ?: Environment.DIRECTORY_DOWNLOADS
        val req = DownloadManager.Request(uri)
            .setTitle(fileName)
            .setDescription("Downloading $fileName")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(dir, fileName)
            .setMimeType(meta.mimeType.ifEmpty { "application/octet-stream" })
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)

        val dmId = dm.enqueue(req)
        pendingDownloads[requestId] = dmId
    }

    fun cancelDownload(requestId: Int) {
        pendingDownloadUrls.remove(requestId)
        val dmId = pendingDownloads.remove(requestId)
        if (dmId != null) {
            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            dm.remove(dmId)
        }
    }

    fun acceptSslError() {
        val handler = pendingSslHandler
        if (handler != null) {
            pendingSslHandler = null
            pendingSslError = null
            webView.post { handler.proceed() }
        }
    }

    fun denySslError() {
        val handler = pendingSslHandler
        if (handler != null) {
            pendingSslHandler = null
            pendingSslError = null
            webView.post { handler.cancel() }
        }
    }

    fun resolveUpload(requestId: Int, filePaths: List<String>) {
        val callback = pendingUploadCallbacks.remove(requestId) ?: return
        val uris = filePaths.map { Uri.parse(it) }.toTypedArray()
        webView.post { callback.onReceiveValue(uris) }
    }

    fun cancelUpload(requestId: Int) {
        val callback = pendingUploadCallbacks.remove(requestId) ?: return
        webView.post { callback.onReceiveValue(null) }
    }

    fun postBridgeMessage(message: String) {
        if (!bridgeEnabled) return
        val escaped = message
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
        val js = "window.dispatchEvent(new CustomEvent('fixit-bridge', {detail: '$escaped'}))"
        webView.post { webView.evaluateJavascript(js, null) }
    }

    // ── Event helpers ──────────────────────────────────────────────────────

    fun sendEvent(type: String, value: Any) {
        val event = HashMap<String, Any>()
        event["type"] = type
        event["value"] = value
        eventSink?.success(event)
    }

    private fun sendNavigationState() {
        val event = HashMap<String, Any>()
        event["type"] = "navigationState"
        event["canGoBack"] = webView.canGoBack()
        event["canGoForward"] = webView.canGoForward()
        eventSink?.success(event)
    }

    private fun sendDiagnosticsEvent(name: String, data: Map<String, Any>) {
        val event = HashMap<String, Any>()
        event["type"] = "diagnostics"
        event["name"] = name
        event.putAll(data)
        eventSink?.success(event)
    }

    // ── PlatformView ──────────────────────────────────────────────────────

    override fun getView(): View = webView

    override fun dispose() {
        FixitWebViewRegistry.remove(viewId)
        eventSink = null
        if (downloadReceiverRegistered) {
            try { context.unregisterReceiver(downloadReceiver) } catch (_: Exception) {}
            downloadReceiverRegistered = false
        }
        pendingDownloadUrls.clear()
        pendingDownloads.clear()
        if (connectivityCallbackRegistered) {
            try {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                cm.unregisterNetworkCallback(connectivityCallback)
            } catch (_: Exception) {}
            connectivityCallbackRegistered = false
        }
        if (bridgeEnabled) {
            webView.removeJavascriptInterface("FixitBridge")
        }
        webView.post { webView.destroy() }
        if (diagnosticsEnabled) FixitProfiler.reset()
    }

    // ── Public navigation API ─────────────────────────────────────────────

    fun loadUrl(url: String) {
        webView.post { webView.loadUrl(url) }
    }

    fun loadHtmlString(html: String, baseUrl: String?) {
        webView.post {
            webView.loadDataWithBaseURL(baseUrl, html, "text/html", "UTF-8", null)
        }
    }

    fun stopLoading() {
        webView.post { webView.stopLoading() }
    }

    fun getTitle(): String? {
        // getTitle must be called on UI thread, but this method is synchronous from Pigeon's perspective.
        // Actually, pigeon made it synchronous on the UI thread for Android automatically if called correctly,
        // but WebView.title is accessible here.
        return webView.title
    }

    fun goBack() {
        webView.post {
            if (webView.canGoBack()) {
                webView.goBack()
            }
        }
    }

    fun goForward() {
        webView.post {
            if (webView.canGoForward()) {
                webView.goForward()
            }
        }
    }

    fun reload() {
        webView.post { webView.reload() }
    }

    fun clearCache() {
        webView.post { webView.clearCache(true) }
    }

    // ── Offline Cache API ──────────────────────────────────────────────────────

    fun setCachedResponse(url: String, data: String, mimeType: String) {
        offlineCache[url] = CacheEntry(data, mimeType)
    }

    fun clearOfflineCache() {
        offlineCache.clear()
    }

    fun setOfflineFallback(html: String) {
        offlineFallbackHtml = html
    }

    fun evaluateJavascript(javascript: String) {
        webView.post { webView.evaluateJavascript(javascript, null) }
    }

    fun runJavascriptReturningResult(javascript: String, callback: (Result<String?>) -> Unit) {
        webView.post {
            webView.evaluateJavascript(javascript) { value ->
                callback(Result.success(value))
            }
        }
    }

    // ── Phase 7: Custom Headers / POST ───────────────────────────────────────

    fun loadUrlWithHeaders(url: String, headers: Map<String?, String?>?, method: String?, body: String?) {
        webView.post {
            if (method?.uppercase() == "POST" && body != null) {
                val postBytes = body.toByteArray(Charsets.UTF_8)
                webView.postUrl(url, postBytes)
            } else if (headers != null && headers.isNotEmpty()) {
                val stringHeaders = headers.entries
                    .filter { it.key != null && it.value != null }
                    .associate { it.key!! to it.value!! }
                webView.loadUrl(url, stringHeaders)
            } else {
                webView.loadUrl(url)
            }
        }
    }

    // ── Phase 7: HTTP Auth Response ──────────────────────────────────────────

    fun httpAuthResponse(requestId: Int, username: String, password: String) {
        if (requestId == pendingHttpAuthRequestId && pendingHttpAuthHandler != null) {
            val handler = pendingHttpAuthHandler!!
            pendingHttpAuthHandler = null
            webView.post { handler.proceed(username, password) }
        }
    }

    fun cancelHttpAuth(requestId: Int) {
        if (requestId == pendingHttpAuthRequestId && pendingHttpAuthHandler != null) {
            val handler = pendingHttpAuthHandler!!
            pendingHttpAuthHandler = null
            webView.post { handler.cancel() }
        }
    }

    // ── Phase A.5: Lifecycle Persistence ───────────────────────────────────────

    fun pause() {
        webView.post {
            // Pause WebView core (stops timers, rendering, media)
            webView.onPause()
            webView.pauseTimers()
        }
    }

    fun resume() {
        webView.post {
            webView.onResume()
            webView.resumeTimers()
        }
    }

    // ── Phase A: Renderer Recovery ────────────────────────────────────────────

    /**
     * Recreates the WebView after a renderer crash, restoring the last URL.
     * The old WebView's state is lost, but we restore navigation history
     * and cookies from the manager.
     */
    fun recreateWebView() {
        val lastUrl = webView.url ?: ""
        val wasOffline = offlineEnabled
        webView.post {
            // Reset state
            pendingSslHandler = null
            pendingSslError = null
            pendingHttpAuthHandler = null
            pendingUploadCallbacks.clear()
            pendingDownloadUrls.clear()
            pendingDownloads.clear()
            firstPaintMarked = false

            // Reload the URL
            if (lastUrl.isNotEmpty() && lastUrl != "about:blank") {
                webView.loadUrl(lastUrl)
            }

            // Emit restarted event
            val restartEvent = HashMap<String, Any>()
            restartEvent["type"] = "rendererRestarted"
            eventSink?.success(restartEvent)
        }
    }

    // ── Phase 7: Update Security Config ──────────────────────────────────────

    fun updateSecurityConfig(mixedContentMode: Long?, safeBrowsingEnabled: Boolean?, zoomEnabled: Boolean?) {
        webView.post {
            val settings = webView.settings
            if (mixedContentMode != null) {
                settings.mixedContentMode = mixedContentMode.toInt()
            }
            if (zoomEnabled != null) {
                settings.setSupportZoom(zoomEnabled)
                settings.builtInZoomControls = zoomEnabled
                settings.displayZoomControls = false
            }
        }
        if (safeBrowsingEnabled != null && safeBrowsingEnabled) {
            try {
                android.webkit.WebView.startSafeBrowsing(context, null)
            } catch (_: Exception) {}
        }
    }
}
