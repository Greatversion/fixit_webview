import 'dart:io';
import 'package:fixit_core/fixit_core.dart';
import 'fixit_runtime_context.dart';
import 'fixit_runtime_info.dart';
import 'lifecycle.dart';
import '../config/fixit_runtime_config.dart';
import '../platform_interface/fixit_webview_platform.dart';
import '../bridge/bridge_manager.dart';

/// An extension point that integrates with a [FixitRuntime].
///
/// Implementations are registered via [FixitRuntime.register] and receive
/// a callback when attached.
abstract class FixitExtensionPlugin {
  /// A unique identifier for this plugin.
  String get id;

  /// Called when the plugin is registered with [runtime].
  void onRegister(FixitRuntime runtime);
}

/// The central runtime that owns a WebView instance and provides access to
/// navigation, bridge communication, lifecycle management, and plugins.
///
/// Create one via [FixitRuntime.create] for a given [viewId] and [context].
class FixitRuntime {
  /// Metadata about this runtime instance (id, SDK version, platform, etc.).
  final FixitRuntimeInfo info;

  /// Services shared by this runtime (logger, cache, cookies, session, events).
  final FixitRuntimeContext context;

  /// Manages the lifecycle (initialize, pause, resume, dispose) of this runtime.
  late final FixitLifecycleManager lifecycle;

  /// The platform-level identifier for the underlying WebView.
  final int viewId;

  final Map<String, FixitExtensionPlugin> _plugins = {};

  /// The bridge manager for JavaScript-to-native message handling.
  final FixitBridgeManager bridgeManager = FixitBridgeManager();

  /// Creates a [FixitRuntime] with the given [info], [context], and [viewId].
  FixitRuntime({
    required this.info,
    required this.context,
    required this.viewId,
  }) {
    lifecycle = FixitLifecycleManager(runtime: this);
  }

  /// Creates a fully initialized [FixitRuntime] for [viewId] using [context].
  ///
  /// Generates [FixitRuntimeInfo] automatically from the current environment.
  static FixitRuntime create(int viewId, FixitRuntimeContext context) {
    final info = FixitRuntimeInfo(
      runtimeId: 'fixit-runtime-$viewId',
      sdkVersion: FixitVersion.sdk,
      platform: Platform.operatingSystem,
      createdAt: DateTime.now(),
    );
    return FixitRuntime(info: info, context: context, viewId: viewId);
  }

  /// Registers an extension [plugin] with this runtime.
  ///
  /// The plugin's [FixitExtensionPlugin.onRegister] is called immediately.
  void register(FixitExtensionPlugin plugin) {
    _plugins[plugin.id] = plugin;
    plugin.onRegister(this);
    context.logger.debug('Registered extension plugin: ${plugin.id}');
  }

  // Hook mechanism
  final List<Future<bool> Function(String url)> _beforeLoadHooks = [];
  final List<void Function(String url)> _afterLoadHooks = [];

  /// Adds a hook that runs before every URL load.
  /// Return `false` from [hook] to cancel the navigation.
  void addBeforeLoadHook(Future<bool> Function(String url) hook) =>
      _beforeLoadHooks.add(hook);

  /// Adds a hook that runs after every successful URL load.
  void addAfterLoadHook(void Function(String url) hook) =>
      _afterLoadHooks.add(hook);

  /// Initializes the runtime lifecycle with the given [config].
  Future<void> initialize(FixitRuntimeConfig config) async {
    await lifecycle.initialize(config);
  }

  /// Loads [url] in the WebView, running before/after load hooks.
  Future<void> loadUrl(String url) async {
    for (final hook in _beforeLoadHooks) {
      final shouldContinue = await hook(url);
      if (!shouldContinue) {
        context.logger.warning('Load URL blocked by hook: $url');
        return;
      }
    }
    await FixitWebViewPlatform.instance.loadUrl(viewId, url);
    for (final hook in _afterLoadHooks) {
      hook(url);
    }
  }

  /// Loads [url] with optional custom [headers], HTTP [method], and POST [body].
  Future<void> loadUrlWithHeaders(
    int viewId,
    String url, {
    Map<String, String>? headers,
    String? method,
    String? body,
  }) async {
    await FixitWebViewPlatform.instance.loadUrlWithHeaders(
      viewId,
      url,
      headers,
      method,
      body,
    );
  }

  /// Loads an HTML [String] into the WebView, optionally specifying [baseUrl].
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    await FixitWebViewPlatform.instance.loadHtmlString(viewId, html, baseUrl);
  }

  /// Stops the current page load.
  Future<void> stopLoading() async {
    await FixitWebViewPlatform.instance.stopLoading(viewId);
  }

  /// Returns the title of the currently loaded page, or `null`.
  Future<String?> getTitle() async {
    return await FixitWebViewPlatform.instance.getTitle(viewId);
  }

  /// Navigates back in the WebView history.
  Future<void> goBack() async {
    await FixitWebViewPlatform.instance.goBack(viewId);
  }

  /// Navigates forward in the WebView history.
  Future<void> goForward() async {
    await FixitWebViewPlatform.instance.goForward(viewId);
  }

  /// Reloads the current page.
  Future<void> reload() async {
    await FixitWebViewPlatform.instance.reload(viewId);
  }

  /// Clears the WebView cache.
  Future<void> clearCache() async {
    await FixitWebViewPlatform.instance.clearCache(viewId);
  }

  /// Clears all cookies managed by the platform.
  Future<void> clearCookies() async {
    await FixitWebViewPlatform.instance.clearCookies();
  }

  /// Evaluates [javascript] in the context of the current page.
  Future<void> evaluateJavascript(String javascript) async {
    await FixitWebViewPlatform.instance.evaluateJavascript(viewId, javascript);
  }

  /// Evaluates [javascript] and returns the resulting value as a String.
  Future<String?> runJavascriptReturningResult(String javascript) async {
    return await FixitWebViewPlatform.instance
        .runJavascriptReturningResult(viewId, javascript);
  }

  /// Sends a bridge [message] to the JavaScript side.
  Future<void> postBridgeMessage(String message) async {
    await FixitWebViewPlatform.instance.postBridgeMessage(viewId, message);
  }

  /// Disposes the runtime and its lifecycle manager.
  Future<void> dispose() async {
    await lifecycle.dispose();
  }
}
