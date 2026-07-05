import 'package:fixit_core/fixit_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'fixit_runtime.dart';
import '../config/fixit_runtime_config.dart';
import '../platform_interface/fixit_webview_platform.dart';

class FixitLifecycleManager {
  final FixitRuntime runtime;
  final FixitLogger _logger;
  bool _isInitialized = false;

  static const MethodChannel _lifecycleChannel =
      MethodChannel('com.fixit.fixit_webview/lifecycle');

  AppLifecycleState _currentState = AppLifecycleState.resumed;

  FixitLifecycleManager({required this.runtime})
      : _logger = FixitLogger(label: 'Lifecycle-${runtime.viewId}');

  Future<void> initialize(FixitRuntimeConfig config) async {
    if (_isInitialized) return;
    _logger.debug(
        'Initializing runtime view ${runtime.viewId} with initial url: ${config.initialUrl}');
    await FixitWebViewPlatform.instance.create(runtime.viewId, config);
    _isInitialized = true;
  }

  Future<void> pause() async {
    if (_currentState == AppLifecycleState.paused ||
        _currentState == AppLifecycleState.hidden) return;
    _currentState = AppLifecycleState.paused;
    _logger.debug('Pausing runtime view ${runtime.viewId}');

    // Flush cookies before background
    await FixitWebViewPlatform.instance.clearCookies();

    // Pause native WebView timers and media
    try {
      await _lifecycleChannel.invokeMethod('pauseWebView', {
        'viewId': runtime.viewId,
      });
    } catch (_) {}

    // Pause JS timers on the page
    try {
      await FixitWebViewPlatform.instance.evaluateJavascript(
        runtime.viewId,
        'window.dispatchEvent(new CustomEvent("fixit-lifecycle", {detail: "pause"}))',
      );
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentState == AppLifecycleState.resumed) return;
    _currentState = AppLifecycleState.resumed;
    _logger.debug('Resuming runtime view ${runtime.viewId}');

    // Resume native WebView timers and media
    try {
      await _lifecycleChannel.invokeMethod('resumeWebView', {
        'viewId': runtime.viewId,
      });
    } catch (_) {}

    // Resume JS timers
    try {
      await FixitWebViewPlatform.instance.evaluateJavascript(
        runtime.viewId,
        'window.dispatchEvent(new CustomEvent("fixit-lifecycle", {detail: "resume"}))',
      );
    } catch (_) {}

    // Restore focus to the WebView
    try {
      await FixitWebViewPlatform.instance.evaluateJavascript(
        runtime.viewId,
        'window.focus()',
      );
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    _logger.debug('Disposing runtime view ${runtime.viewId}');
    await FixitWebViewPlatform.instance.dispose(runtime.viewId);
    _isInitialized = false;
  }

  Future<void> destroy() async {
    await dispose();
    _logger.debug('Destroyed runtime view ${runtime.viewId}');
  }
}
