package com.fixit.fixit_webview

import android.Manifest
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.webkit.CookieManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.fixit.fixit_webview.webview.FixitWebViewFactory
import com.fixit.fixit_webview.webview.FixitWebViewHostApi
import com.fixit.fixit_webview.webview.FixitWebViewRegistry
import com.fixit.fixit_webview.webview.PigeonRuntimeConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Main Flutter plugin entry point.
 * Registers the PlatformView factory, the Pigeon host API, and the permission MethodChannel.
 */
class FixitWebviewPlugin : FlutterPlugin, FixitWebViewHostApi, ActivityAware, MethodChannel.MethodCallHandler, ComponentCallbacks2 {

    private var context: Context? = null
    private var application: android.app.Application? = null
    private var messenger: BinaryMessenger? = null
    private var activity: android.app.Activity? = null
    private var permissionChannel: MethodChannel? = null
    private var uploadChannel: MethodChannel? = null
    private var downloadChannel: MethodChannel? = null
    private var navigationChannel: MethodChannel? = null
    private var offlineChannel: MethodChannel? = null
    private var lifecycleChannel: MethodChannel? = null

    // ── Permission request tracking ────────────────────────────────
    private val pendingPermissionRequests = mutableMapOf<Int, MethodChannel.Result>()
    private var permissionRequestCode = 3000
    private val permissionRequestCodeMap = mutableMapOf<Int, List<String>>()

    companion object {
        private const val PERMISSION_CHANNEL = "com.fixit.fixit_webview/permissions"
        private const val UPLOAD_CHANNEL = "com.fixit.fixit_webview/upload"
        private const val DOWNLOAD_CHANNEL = "com.fixit.fixit_webview/download"
        private const val NAVIGATION_CHANNEL = "com.fixit.fixit_webview/navigation"
        private const val OFFLINE_CHANNEL = "com.fixit.fixit_webview/offline"
        private const val LIFECYCLE_CHANNEL = "com.fixit.fixit_webview/lifecycle"
    }

    // ─── FlutterPlugin ────────────────────────────────────────
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger

        // Register for memory pressure events
        if (binding.applicationContext is android.app.Application) {
            application = binding.applicationContext as android.app.Application
            application?.registerComponentCallbacks(this)
        }

        binding.platformViewRegistry.registerViewFactory(
            "com.fixit.fixit_webview/view",
            FixitWebViewFactory(binding.binaryMessenger)
        )

        FixitWebViewHostApi.setUp(binding.binaryMessenger, this)

        permissionChannel = MethodChannel(binding.binaryMessenger, PERMISSION_CHANNEL)
        permissionChannel?.setMethodCallHandler(this)
        uploadChannel = MethodChannel(binding.binaryMessenger, UPLOAD_CHANNEL)
        uploadChannel?.setMethodCallHandler(this)
        downloadChannel = MethodChannel(binding.binaryMessenger, DOWNLOAD_CHANNEL)
        downloadChannel?.setMethodCallHandler(this)
        navigationChannel = MethodChannel(binding.binaryMessenger, NAVIGATION_CHANNEL)
        navigationChannel?.setMethodCallHandler(this)
        offlineChannel = MethodChannel(binding.binaryMessenger, OFFLINE_CHANNEL)
        offlineChannel?.setMethodCallHandler(this)
        lifecycleChannel = MethodChannel(binding.binaryMessenger, LIFECYCLE_CHANNEL)
        lifecycleChannel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        application?.unregisterComponentCallbacks(this)
        application = null
        FixitWebViewHostApi.setUp(binding.binaryMessenger, null)
        permissionChannel?.setMethodCallHandler(null)
        permissionChannel = null
        uploadChannel?.setMethodCallHandler(null)
        uploadChannel = null
        downloadChannel?.setMethodCallHandler(null)
        downloadChannel = null
        navigationChannel?.setMethodCallHandler(null)
        navigationChannel = null
        offlineChannel?.setMethodCallHandler(null)
        offlineChannel = null
        lifecycleChannel?.setMethodCallHandler(null)
        lifecycleChannel = null
        context = null
        messenger = null
    }

    // ─── ActivityAware ────────────────────────────────────────────
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionResultListener)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── Phase A: Memory Pressure (ComponentCallbacks2) ────────────────────────
    override fun onTrimMemory(level: Int) {
        val pressureLevel = when {
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> "critical"
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE -> "moderate"
            else -> "none"
        }
        if (pressureLevel != "none") {
            FixitWebViewRegistry.broadcastEvent("memoryPressure", pressureLevel)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {}
    override fun onLowMemory() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    // ─── Permission Result Listener ───────────────────────────────
    private val permissionResultListener = PluginRegistry.RequestPermissionsResultListener { requestCode, permissions, grantResults ->
        val code = requestCode
        if (permissionRequestCodeMap.containsKey(code)) {
            val requestedPermissions = permissionRequestCodeMap.remove(code)
            val result = pendingPermissionRequests.remove(code)
            if (result != null && requestedPermissions != null) {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                result.success(if (allGranted) 0 else 1) // 0 = granted, 1 = denied
            }
            true
        } else {
            false
        }
    }

    // ─── MethodChannel (Permissions) ──────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val ctx = context
        if (act == null || ctx == null) {
            result.error("NO_ACTIVITY", "Plugin not attached to activity", null)
            return
        }

        when (call.method) {
            "startDownload" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val requestId = call.argument<Int>("requestId") ?: run {
                    result.success(false)
                    return
                }
                val destinationDir = call.argument<String>("destinationDir")
                val view = FixitWebViewRegistry.get(viewId)
                if (view != null) {
                    // The native listener already has the URL. We start the download using
                    // the DownloadManager. Since we don't store the URL per requestId on the native
                    // side (it was already sent via event), we use the view's generic startDownload
                    // that fetches from the pending event context.
                    view.startDownload(requestId, destinationDir)
                }
                result.success(true)
            }
            "cancelDownload" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val requestId = call.argument<Int>("requestId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.cancelDownload(requestId)
                result.success(true)
            }
            "resolveUpload" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val requestId = call.argument<Int>("requestId") ?: run {
                    result.success(false)
                    return
                }
                val filePaths = call.argument<List<String>>("filePaths") ?: emptyList()
                FixitWebViewRegistry.get(viewId)?.resolveUpload(requestId, filePaths)
                result.success(true)
            }
            "cancelUpload" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val requestId = call.argument<Int>("requestId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.cancelUpload(requestId)
                result.success(true)
            }
            "acceptSslError" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.acceptSslError()
                result.success(true)
            }
            "denySslError" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.denySslError()
                result.success(true)
            }
            "setCachedResponse" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val url = call.argument<String>("url") ?: run {
                    result.success(false)
                    return
                }
                val data = call.argument<String>("data") ?: run {
                    result.success(false)
                    return
                }
                val mimeType = call.argument<String>("mimeType") ?: "text/html"
                FixitWebViewRegistry.get(viewId)?.setCachedResponse(url, data, mimeType)
                result.success(true)
            }
            "clearOfflineCache" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.clearOfflineCache()
                result.success(true)
            }
            "setOfflineFallback" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                val html = call.argument<String>("html") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.setOfflineFallback(html)
                result.success(true)
            }
            "openDownloadedFile" -> {
                val filePath = call.argument<String>("filePath") ?: run {
                    result.success(false)
                    return
                }
                val mimeType = call.argument<String>("mimeType") ?: run {
                    result.success(false)
                    return
                }
                try {
                    val uri = Uri.parse(filePath)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, mimeType)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    act.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            "checkPermission" -> {
                val type = call.argument<Int>("type") ?: 0
                val permission = permissionForType(type)
                if (permission == null) {
                    result.success(1) // denied
                    return
                }
                val status = checkAndroidPermission(ctx, permission)
                result.success(status.ordinal)
            }
            "requestPermission" -> {
                val type = call.argument<Int>("type") ?: 0
                val permission = permissionForType(type)
                if (permission == null) {
                    result.success(1) // denied
                    return
                }
                if (checkAndroidPermission(ctx, permission) == PermissionStatus.GRANTED) {
                    result.success(0) // granted
                    return
                }
                val code = permissionRequestCode++
                pendingPermissionRequests[code] = result
                permissionRequestCodeMap[code] = listOf(permission)
                ActivityCompat.requestPermissions(act, arrayOf(permission), code)
            }
            "pauseWebView" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.pause()
                result.success(true)
            }
            "resumeWebView" -> {
                val viewId = call.argument<Int>("viewId") ?: run {
                    result.success(false)
                    return
                }
                FixitWebViewRegistry.get(viewId)?.resume()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private enum class PermissionStatus {
        GRANTED, DENIED
    }

    private fun checkAndroidPermission(ctx: Context, permission: String): PermissionStatus {
        return if (ContextCompat.checkSelfPermission(ctx, permission) == PackageManager.PERMISSION_GRANTED) {
            PermissionStatus.GRANTED
        } else {
            PermissionStatus.DENIED
        }
    }

    private fun permissionForType(type: Int): String? {
        return when (type) {
            0 -> Manifest.permission.CAMERA
            1 -> Manifest.permission.RECORD_AUDIO
            2 -> Manifest.permission.ACCESS_FINE_LOCATION
            else -> null
        }
    }

    // ─── FixitWebViewHostApi (Pigeon) ─────────────────────────
    override fun create(viewId: Long, config: PigeonRuntimeConfig) {
        val id = viewId.toInt()
        val view = FixitWebViewRegistry.get(id)
        if (view != null) {
            view.applyConfig(config)
        } else {
            FixitWebViewRegistry.setPendingConfig(id, config)
        }
    }

    override fun loadUrl(viewId: Long, url: String) {
        FixitWebViewRegistry.get(viewId.toInt())?.loadUrl(url)
    }

    override fun loadUrlWithHeaders(viewId: Long, url: String, headers: Map<String?, String?>?, method: String?, body: String?) {
        FixitWebViewRegistry.get(viewId.toInt())?.loadUrlWithHeaders(url, headers, method, body)
    }

    override fun loadHtmlString(viewId: Long, html: String, baseUrl: String?) {
        FixitWebViewRegistry.get(viewId.toInt())?.loadHtmlString(html, baseUrl)
    }

    override fun stopLoading(viewId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.stopLoading()
    }

    override fun getTitle(viewId: Long): String? {
        return FixitWebViewRegistry.get(viewId.toInt())?.getTitle()
    }

    override fun goBack(viewId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.goBack()
    }

    override fun goForward(viewId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.goForward()
    }

    override fun reload(viewId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.reload()
    }

    override fun clearCache(viewId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.clearCache()
    }

    override fun clearCookies() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.removeAllCookies(null)
        cookieManager.flush()
    }

    override fun setCookie(url: String, key: String, value: String) {
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setCookie(url, "$key=$value")
    }

    override fun getCookies(url: String, callback: (Result<List<String?>>) -> Unit) {
        val raw = CookieManager.getInstance().getCookie(url) ?: ""
        val cookies = if (raw.isEmpty()) emptyList() else raw.split(";").map { it.trim() }
        callback(Result.success(cookies))
    }

    override fun postBridgeMessage(viewId: Long, message: String) {
        FixitWebViewRegistry.get(viewId.toInt())?.postBridgeMessage(message)
    }

    override fun httpAuthResponse(viewId: Long, requestId: Long, username: String, password: String) {
        FixitWebViewRegistry.get(viewId.toInt())?.httpAuthResponse(requestId.toInt(), username, password)
    }

    override fun cancelHttpAuth(viewId: Long, requestId: Long) {
        FixitWebViewRegistry.get(viewId.toInt())?.cancelHttpAuth(requestId.toInt())
    }

    override fun updateSecurityConfig(viewId: Long, mixedContentMode: Long?, safeBrowsingEnabled: Boolean?, zoomEnabled: Boolean?) {
        FixitWebViewRegistry.get(viewId.toInt())?.updateSecurityConfig(mixedContentMode, safeBrowsingEnabled, zoomEnabled)
    }

    override fun evaluateJavascript(viewId: Long, javascript: String) {
        FixitWebViewRegistry.get(viewId.toInt())?.evaluateJavascript(javascript)
    }

    override fun runJavascriptReturningResult(
        viewId: Long,
        javascript: String,
        callback: (Result<String?>) -> Unit
    ) {
        val view = FixitWebViewRegistry.get(viewId.toInt())
        if (view != null) {
            view.runJavascriptReturningResult(javascript, callback)
        } else {
            callback(Result.failure(Exception("WebView not found for viewId: $viewId")))
        }
    }

    override fun dispose(viewId: Long) {
        FixitWebViewRegistry.remove(viewId.toInt())?.dispose()
    }
}
