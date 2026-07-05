package com.fixit.fixit_webview.webview

import java.util.HashMap
import java.util.concurrent.ConcurrentHashMap

/**
 * Global registry mapping viewId -> FixitWebView.
 * The PlatformView factory registers views here when Flutter renders them.
 * The Pigeon plugin handler looks views up here for loadUrl/goBack etc.
 * This eliminates the dual-instance problem where two separate WebView objects
 * were created for the same viewId.
 */
object FixitWebViewRegistry {
    private val registry = ConcurrentHashMap<Int, FixitWebView>()
    private val pendingConfigs = ConcurrentHashMap<Int, PigeonRuntimeConfig>()

    fun register(viewId: Int, webView: FixitWebView) {
        registry[viewId] = webView
        val config = pendingConfigs.remove(viewId)
        if (config != null) {
            webView.applyConfig(config)
        }
    }

    fun get(viewId: Int): FixitWebView? = registry[viewId]

    fun remove(viewId: Int): FixitWebView? {
        pendingConfigs.remove(viewId)
        return registry.remove(viewId)
    }

    fun setPendingConfig(viewId: Int, config: PigeonRuntimeConfig) {
        pendingConfigs[viewId] = config
    }

    /** Broadcast an event to all registered WebViews. */
    fun broadcastEvent(type: String, value: Any) {
        for (view in registry.values) {
            view.sendEvent(type, value)
        }
    }
}
