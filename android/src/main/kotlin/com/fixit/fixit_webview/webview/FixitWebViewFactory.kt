package com.fixit.fixit_webview.webview

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory called by Flutter when it renders a FixitWebView widget.
 * Creates the native WebView and registers it in FixitWebViewRegistry.
 * The Pigeon plugin handler then finds the same instance via the registry.
 *
 * Reads optional creation param "diagnosticsLevel" (String, one of
 * "startup" | "performance" | "verbose").
 * When present and non-empty, the internal FixitProfiler is activated.
 * This is never exposed as a public SDK concern; it is only consumed by
 * the benchmark/diagnostic tool.
 */
class FixitWebViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val viewId = (params?.get("viewId") as? Number)?.toInt() ?: id
        val diagnosticsLevel = params?.get("diagnosticsLevel") as? String

        // ── T1: PlatformView created ──────────────────────────────────────
        if (!diagnosticsLevel.isNullOrEmpty()) FixitProfiler.markT1PlatformViewCreated()

        // FixitWebView registers itself into FixitWebViewRegistry inside its init block.
        return FixitWebView(context, viewId, messenger, diagnosticsLevel = diagnosticsLevel)
    }
}
