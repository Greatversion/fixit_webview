import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../runtime/fixit_runtime.dart';
import '../runtime/diagnostics.dart' hide StartupMilestone;
import '../internal/diagnostics_models.dart';
import '../internal/startup_registry.dart';
import '../bridge/bridge_manager.dart';
import '../bridge/bridge_handler.dart';
import '../permissions/permission_manager.dart';
import '../config/native_feature_registry.dart';
import '../cookie/fixit_cookie_manager.dart';
import '../cookie/fixit_session_manager.dart';
import '../navigation/oauth_interceptor.dart';
import '../navigation/navigation_engine.dart';
import '../upload/upload_engine.dart';
import '../download/download_engine.dart';
import '../offline/offline_engine.dart';
import '../theme/theme_engine.dart';

// -- Event data classes --------------------------------------------------------

/// Holds the current scroll position and scroll delta of the WebView content.
class ScrollUpdate {
  /// The horizontal scroll offset in pixels.
  final int x;

  /// The vertical scroll offset in pixels.
  final int y;

  /// The horizontal delta since the last scroll event.
  final int dx;

  /// The vertical delta since the last scroll event.
  final int dy;

  /// Creates a [ScrollUpdate] with the given position and delta values.
  const ScrollUpdate({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
  });

  @override
  String toString() => 'ScrollUpdate(x: $x, y: $y, dx: $dx, dy: $dy)';
}

/// Describes a WebView renderer crash event including the view identifier and
/// optional crash details.
class WebViewCrashEvent {
  /// The platform view identifier of the crashed WebView.
  final int viewId;

  /// An optional human-readable description of the crash.
  final String? description;

  /// Whether the renderer process was dropped (true) or the whole WebView
  /// became unusable (false).
  final bool rendererDropped;

  /// Creates a [WebViewCrashEvent] with the given [viewId], optional
  /// [description], and [rendererDropped] flag.
  const WebViewCrashEvent({
    required this.viewId,
    this.description,
    this.rendererDropped = false,
  });

  @override
  String toString() =>
      'WebViewCrashEvent(viewId: $viewId, rendererDropped: $rendererDropped)';
}

/// Memory pressure levels reported by the OS.
///
/// * [none] -- normal memory conditions.
/// * [moderate] -- the OS is beginning to reclaim memory; consider clearing
///   non-essential caches.
/// * [critical] -- the OS is under severe memory pressure; aggressive cache
///   clearing is recommended.
enum MemoryPressureLevel { none, moderate, critical }

/// The main controller for a [FixitWebView] widget.
///
/// Provides methods for navigation, JavaScript execution, cookie management,
/// file uploads/downloads, permissions, OAuth interception, bridge
/// communication, and lifecycle management. Access sub-engines such as
/// [navigationEngine], [downloadEngine], [uploadEngine], [offlineEngine],
/// and [themeEngine] for granular control over specific features.
class FixitWebViewController {
  final FixitRuntime _runtime;

  /// The unique platform view identifier assigned to this WebView instance.
  int get viewId => _runtime.viewId;

  final Map<String, Completer<dynamic>> _pendingInvocations = {};
  int _callbackIdCounter = 0;
  static const Duration _invokeTimeout = Duration(seconds: 60);

  String _nextCallbackId() => 'fixit_rpc_${++_callbackIdCounter}';

  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _currentUrl = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _pageTitle = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _canGoBack = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _canGoForward = ValueNotifier<bool>(false);
  final ValueNotifier<ScrollUpdate> _scrollOffset = ValueNotifier<ScrollUpdate>(
    ScrollUpdate(x: 0, y: 0, dx: 0, dy: 0),
  );

  // -- Phase A: Production Hardening ---------------------------------------

  final ValueNotifier<bool> _firstPaint = ValueNotifier<bool>(false);
  bool _firstPaintFired = false;

  final StreamController<WebViewCrashEvent> _crashController =
      StreamController<WebViewCrashEvent>.broadcast();

  final StreamController<void> _restartController =
      StreamController<void>.broadcast();

  final ValueNotifier<MemoryPressureLevel> _memoryPressureLevel =
      ValueNotifier<MemoryPressureLevel>(MemoryPressureLevel.none);

  /// Fires when the first meaningful paint occurs (progress >= 10%).
  ValueListenable<bool> get onFirstPaint => _firstPaint;

  /// Fires when the WebView renderer crashes.
  Stream<WebViewCrashEvent> get onCrash => _crashController.stream;

  /// Fires when the WebView is automatically restored after a crash.
  Stream<void> get onRestart => _restartController.stream;

  /// Current OS memory pressure level.
  ValueListenable<MemoryPressureLevel> get memoryPressureLevel =>
      _memoryPressureLevel;

  /// The page load progress as a value between 0.0 and 1.0.
  ValueListenable<double> get progress => _progress;

  /// Whether the WebView is currently loading a page.
  ValueListenable<bool> get loading => _loading;

  /// The URL of the currently loaded page.
  ValueListenable<String?> get currentUrl => _currentUrl;

  /// The title of the currently loaded page.
  ValueListenable<String?> get pageTitle => _pageTitle;

  /// Whether it is possible to navigate back in the history stack.
  ValueListenable<bool> get canGoBack => _canGoBack;

  /// Whether it is possible to navigate forward in the history stack.
  ValueListenable<bool> get canGoForward => _canGoForward;

  /// The current scroll offset of the WebView content.
  ValueListenable<ScrollUpdate> get scrollOffset => _scrollOffset;

  late final EventChannel _eventChannel;
  bool _eventChannelInitialized = false;

  /// Download engine for managing file downloads from the page.
  final FixitDownloadEngine downloadEngine = FixitDownloadEngine();

  /// Navigation engine for intercepting navigation and SSL errors.
  final FixitNavigationEngine navigationEngine = FixitNavigationEngine();

  /// Offline engine for cache strategies and connectivity monitoring.
  final FixitOfflineEngine offlineEngine = FixitOfflineEngine();

  /// Theme engine for injecting CSS themes into the WebView.
  late final FixitThemeEngine themeEngine = FixitThemeEngine(
    evaluateJavascript: evaluateJavascript,
  );

  /// Fired when the page triggers a file upload.
  final _uploadRequestedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Upload engine for managing file upload requests from the page.
  final FixitUploadEngine uploadEngine = FixitUploadEngine();

  @Deprecated('Use uploadEngine.onUploadRequested instead')
  Stream<Map<String, dynamic>> get onUploadRequested =>
      _uploadRequestedController.stream;

  /// Bridge manager for JS <-> Dart communication.
  FixitBridgeManager get bridgeManager => _runtime.bridgeManager;

  /// @internal -- typed diagnostics stream.
  final _diagnosticsController =
      StreamController<StartupTimelineEvent>.broadcast();

  /// @internal -- Do NOT expose in public docs.
  Stream<StartupTimelineEvent> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Creates a [FixitWebViewController] backed by the given [FixitRuntime].
  ///
  /// Typically instantiated automatically by [FixitWebView]; manual
  /// construction is only needed for advanced use cases.
  FixitWebViewController(this._runtime) {
    offlineEngine.viewId = _runtime.viewId;
  }

  /// Set up the EventChannel subscription.
  /// Must be called AFTER the native platform view is created (i.e. after the
  /// FixitWebView widget has been laid out), otherwise the native stream
  /// handler won't exist yet and events will be silently dropped.
  void initializeEventChannel() {
    if (_eventChannelInitialized) return;
    _eventChannelInitialized = true;
    _eventChannel =
        EventChannel('com.fixit.fixit_webview/events_${_runtime.viewId}');
    _setupEventChannel();
  }

  void _setupEventChannel() {
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final map = event.cast<String, dynamic>();
        final type = map['type'] as String;
        switch (type) {
          case 'progress':
            _progress.value = (map['value'] as num).toDouble();
            if (!_firstPaintFired && _progress.value >= 0.1) {
              _firstPaintFired = true;
              _firstPaint.value = true;
            }
            break;
          case 'loading':
            _loading.value = map['value'] as bool;
            if (!_firstPaintFired && !_loading.value) {
              _firstPaintFired = true;
              _firstPaint.value = true;
            }
            break;
          case 'url':
            final newUrl = map['value'] as String?;
            _currentUrl.value = newUrl;
            if (newUrl != null) {
              _oAuthInterceptor.analyze(newUrl);
              navigationEngine.history.push(NavigationEntry(
                url: newUrl,
                title: _pageTitle.value,
                timestamp: DateTime.now(),
              ));
            }
            break;
          case 'title':
            final newTitle = map['value'] as String?;
            _pageTitle.value = newTitle;
            if (newTitle != null && navigationEngine.history.current != null) {
              navigationEngine.history.replaceCurrent(NavigationEntry(
                url: navigationEngine.history.current!.url,
                title: newTitle,
                timestamp: DateTime.now(),
              ));
            }
            break;
          case 'navigationState':
            _canGoBack.value = map['canGoBack'] as bool? ?? false;
            _canGoForward.value = map['canGoForward'] as bool? ?? false;
            break;
          case 'consoleMessage':
            _runtime.context.logger.info('JS Console: ${map['message']}');
            break;
          case 'bridgeMessage':
            _onBridgeMessage(
                map['value'] as String? ?? map['message'] as String? ?? '');
            break;
          case 'downloadRequested':
            downloadEngine.registerRequest(DownloadRequest(
              requestId: (map['requestId'] as num?)?.toInt() ?? 0,
              url: (map['url'] as String?) ?? '',
              mimeType: (map['mimeType'] as String?) ?? '',
              contentLength: (map['contentLength'] as num?)?.toInt() ?? 0,
              contentDisposition: (map['contentDisposition'] as String?) ?? '',
            ));
            break;
          case 'downloadProgress':
            downloadEngine.handleProgress(
              (map['requestId'] as num?)?.toInt() ?? 0,
              (map['receivedBytes'] as num?)?.toInt() ?? 0,
              (map['totalBytes'] as num?)?.toInt() ?? 0,
            );
            break;
          case 'downloadCompleted':
            downloadEngine.handleCompleted(
              (map['requestId'] as num?)?.toInt() ?? 0,
              (map['filePath'] as String?) ?? '',
            );
            break;
          case 'downloadFailed':
            downloadEngine.handleFailed(
              (map['requestId'] as num?)?.toInt() ?? 0,
              (map['error'] as String?) ?? 'Unknown error',
            );
            break;
          case 'uploadRequested':
            _uploadRequestedController.add(map);
            uploadEngine.registerRequest(UploadRequest(
              requestId: (map['requestId'] as num?)?.toInt() ?? 0,
              acceptTypes: (map['acceptTypes'] as List?)?.cast<String>() ?? [],
              isCaptureEnabled: (map['isCaptureEnabled'] as bool?) ?? false,
              allowsMultipleSelection:
                  (map['allowsMultipleSelection'] as bool?) ?? false,
            ));
            break;
          case 'scroll':
            _scrollOffset.value = ScrollUpdate(
              x: (map['x'] as num).toInt(),
              y: (map['y'] as num).toInt(),
              dx: (map['dx'] as num).toInt(),
              dy: (map['dy'] as num).toInt(),
            );
            break;
          case 'navigationRequested':
            navigationEngine.handleNavigationRequest(NavigationRequest(
              url: (map['url'] as String?) ?? '',
              isMainFrame: (map['isMainFrame'] as bool?) ?? true,
              isRedirect: (map['isRedirect'] as bool?) ?? false,
              navigationType: (map['navigationType'] as String?) ?? 'other',
            ));
            break;
          case 'error':
          case 'httpError':
            _runtime.context.logger
                .error('Native error [$type]: ${map['message']}');
            break;
          case 'sslError':
            _runtime.context.logger
                .error('Native error [$type]: ${map['message']}');
            navigationEngine.handleSslError(SslErrorEvent(
              url: (map['url'] as String?) ?? '',
              error: (map['message'] as String?) ?? 'Unknown SSL error',
              host: (map['host'] as String?) ?? (map['url'] as String?) ?? '',
            ));
            break;
          case 'httpAuthRequested':
            navigationEngine.handleHttpAuthRequest(HttpAuthRequest(
              host: (map['host'] as String?) ?? '',
              realm: (map['realm'] as String?) ?? '',
              port: (map['port'] as num?)?.toInt() ?? 0,
              requestId: (map['requestId'] as num?)?.toInt() ?? 0,
            ));
            break;
          case 'navigationBlocked':
            navigationEngine.handleBlockedNavigation(BlockedNavigation(
              url: (map['url'] as String?) ?? '',
              reason: (map['reason'] as String?) ?? 'blocked',
            ));
            break;
          case 'connectivityChanged':
            final stateStr = map['value'] as String? ?? 'online';
            offlineEngine.handleConnectivityChange(
              stateStr == 'offline'
                  ? ConnectivityState.offline
                  : ConnectivityState.online,
            );
            break;
          case 'rendererCrashed':
            _crashController.add(WebViewCrashEvent(
              viewId: viewId,
              description: map['description'] as String?,
              rendererDropped: (map['rendererDropped'] as bool?) ?? false,
            ));
            break;
          case 'rendererRestarted':
            _restartController.add(null);
            break;
          case 'memoryPressure':
            final level = switch (map['value'] as String? ?? 'none') {
              'moderate' => MemoryPressureLevel.moderate,
              'critical' => MemoryPressureLevel.critical,
              _ => MemoryPressureLevel.none,
            };
            _memoryPressureLevel.value = level;
            if (level != MemoryPressureLevel.none) {
              _handleMemoryPressure(level);
            }
            break;
          case 'diagnostics':
            _handleDiagnosticsEvent(map);
            break;
        }
      }
    }, onError: (dynamic error) {
      _runtime.context.logger.error('Error on event channel: $error');
    });
  }

  void _handleDiagnosticsEvent(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    if (name == 'startupTimeline') {
      _emitStartupTimeline(map);
    }
  }

  void _emitStartupTimeline(Map<String, dynamic> map) {
    final rawTimeline = map['timeline'] as String? ?? '';
    final nativeMs =
        (map['milestones'] as Map?)?.cast<String, int>() ?? <String, int>{};
    final milestones = <StartupMilestone>[];

    final t0 = fixitStartupRegistry.getT0(viewId);
    if (t0 != null) {
      milestones.add(StartupMilestone(
        name: 'T0_flutter_widget_inserted',
        epochMs: t0,
      ));
      fixitStartupRegistry.clear(viewId);
    }

    for (final entry in nativeMs.entries) {
      milestones.add(StartupMilestone(name: entry.key, epochMs: entry.value));
    }

    milestones.sort((a, b) => a.epochMs.compareTo(b.epochMs));

    _diagnosticsController.add(StartupTimelineEvent(
      viewId: viewId,
      milestones: milestones,
      rawTimeline: rawTimeline,
    ));
  }

  /// Loads the given [url] in the WebView.
  ///
  /// Replaces the current page with the content at [url].
  Future<void> loadUrl(String url) async {
    await _runtime.loadUrl(url);
  }

  /// Load a URL with custom HTTP headers and optional POST body.
  Future<void> loadUrlWithHeaders(
    String url, {
    Map<String, String>? headers,
    String? method,
    String? body,
  }) async {
    await _runtime.loadUrlWithHeaders(viewId, url,
        headers: headers, method: method, body: body);
  }

  /// Loads the given [html] string in the WebView.
  ///
  /// An optional [baseUrl] can be used to resolve relative URLs in the HTML.
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    await _runtime.loadHtmlString(html, baseUrl: baseUrl);
  }

  /// Stops the current page load.
  Future<void> stopLoading() async {
    await _runtime.stopLoading();
  }

  /// Returns the title of the currently loaded page, or `null` if unavailable.
  Future<String?> getTitle() async {
    return await _runtime.getTitle();
  }

  /// Navigates back one step in the WebView's history stack.
  Future<void> goBack() async {
    await _runtime.goBack();
  }

  /// Navigates forward one step in the WebView's history stack.
  Future<void> goForward() async {
    await _runtime.goForward();
  }

  /// Reloads the current page.
  Future<void> reload() async {
    await _runtime.reload();
  }

  /// Clears the WebView's cached data (cache partition only).
  Future<void> clearCache() async {
    await _runtime.clearCache();
  }

  /// Evaluates the given [javascript] string in the context of the current page.
  ///
  /// Does not return a result. Use [runJavascriptReturningResult] when the
  /// return value is needed.
  Future<void> evaluateJavascript(String javascript) async {
    await _runtime.evaluateJavascript(javascript);
  }

  /// Evaluates the given [javascript] string and returns its result.
  ///
  /// The JavaScript expression must return a value that can be JSON-serialized.
  Future<String?> runJavascriptReturningResult(String javascript) async {
    return await _runtime.runJavascriptReturningResult(javascript);
  }

  /// Register a handler for bridge messages from JavaScript.
  void registerBridgeHandler(String name, BridgeHandler handler) {
    _runtime.bridgeManager.register(name, handler);
  }

  /// Post a message from Dart to JavaScript.
  /// The page receives it via a `fixit-bridge` custom event on `window`.
  Future<void> postBridgeMessage(String message) async {
    await _runtime.postBridgeMessage(message);
  }

  /// Invoke a named action on the JavaScript side and await the response.
  ///
  /// This is an RPC-style call: Dart sends a request to the page,
  /// the page processes it and sends back a result, and the returned
  /// Future completes with that result.
  ///
  /// Example:
  /// ```dart
  /// final user = await controller.invoke('getUser', {'id': 42});
  /// ```
  Future<dynamic> invoke(String action,
      [Map<String, dynamic> data = const {}]) async {
    final callbackId = _nextCallbackId();
    final completer = Completer<dynamic>();
    _pendingInvocations[callbackId] = completer;

    final message = jsonEncode({
      'handlerName': 'invoke',
      'action': action,
      'data': data,
      'callbackId': callbackId,
    });

    // Timeout cleanup
    Future.delayed(_invokeTimeout, () {
      if (_pendingInvocations.containsKey(callbackId)) {
        _pendingInvocations.remove(callbackId);
        completer.completeError(
          TimeoutException(
              'Bridge invoke timed out after ${_invokeTimeout.inSeconds}s: $action'),
        );
      }
    });

    try {
      await postBridgeMessage(message);
    } catch (e) {
      _pendingInvocations.remove(callbackId);
      throw Exception('Failed to send bridge invoke: $e');
    }

    return completer.future;
  }

  /// @internal
  void _onBridgeMessage(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final callbackId = decoded['callbackId'] as String?;

      // -- Response from JS (completes a pending invoke) -----------
      if (callbackId != null && _pendingInvocations.containsKey(callbackId)) {
        final completer = _pendingInvocations.remove(callbackId)!;
        final error = decoded['error'];
        if (error != null) {
          completer.completeError(Exception('$error'));
        } else {
          completer.complete(decoded['result']);
        }
        return;
      }

      // -- Request from JS (route to bridge manager, send result back) --
      _runtime.bridgeManager.handleMessage(decoded).then((result) {
        if (callbackId != null) {
          final response = jsonEncode({
            'callbackId': callbackId,
            'result': result is Map ? result['result'] : result,
            'error': result is Map ? result['error'] : null,
          });
          postBridgeMessage(response);
        }
      });
    } catch (e) {
      _runtime.context.logger.error('Failed to decode bridge message: $e');
    }
  }

  // -- Cookie & Session API -------------------------------------------------

  /// The cookie manager for reading and writing HTTP cookies.
  FixitCookieManager get cookieManager => _runtime.context.cookies;

  /// The session manager for clearing session data.
  FixitSessionManager get sessionManager => _runtime.context.session;

  final FixitOAuthInterceptor _oAuthInterceptor = FixitOAuthInterceptor();

  /// The interceptor that detects OAuth callback URLs during navigation.
  FixitOAuthInterceptor get oAuthInterceptor => _oAuthInterceptor;

  /// Sets a cookie with the given [key] and [value] for the given [url].
  Future<void> setCookie(String url, String key, String value) =>
      cookieManager.setCookie(url, key, value);

  /// Returns all cookies stored for the given [url].
  Future<List<String>> getCookies(String url) => cookieManager.getCookies(url);

  /// Clears all cookies managed by the WebView.
  Future<void> clearCookies() => cookieManager.clearCookies();

  /// Clears the current session data (cookies, localStorage, etc.).
  Future<void> clearSession() => sessionManager.clearSession();

  /// Register an OAuth callback URL pattern.
  ///
  /// When the WebView navigates to a URL matching [pattern], the
  /// [oAuthInterceptor] will fire the associated callback.
  void registerOAuthCallbackPattern(String pattern) {
    _oAuthInterceptor.addCallbackPattern(pattern);
  }

  // -- Upload API -----------------------------------------------------------

  /// Resolves a file upload request by providing the selected [filePaths].
  ///
  /// [requestId] must match the ID from the upload request event.
  Future<void> selectFiles(int requestId, List<String> filePaths) =>
      uploadEngine.resolveUpload(viewId, requestId, filePaths);

  /// Cancels a pending file upload request identified by [requestId].
  Future<void> cancelUpload(int requestId) =>
      uploadEngine.cancelUpload(viewId, requestId);

  /// Call when a navigation event occurs so the OAuth interceptor can analyze it.
  /// Returns true if the URL matched an OAuth callback.
  bool checkOAuthCallback(String url) => _oAuthInterceptor.analyze(url);

  // -- Download API ---------------------------------------------------------

  /// Accepts a download request with the given [requestId].
  ///
  /// An optional [destinationDir] can override the default download directory.
  Future<void> acceptDownload(int requestId, {String? destinationDir}) =>
      downloadEngine.acceptDownload(viewId, requestId,
          destinationDir: destinationDir);

  /// Cancels a download identified by [requestId].
  Future<void> cancelDownload(int requestId) =>
      downloadEngine.cancelDownload(requestId);

  /// Opens the downloaded file at [filePath] with the system handler for the
  /// given [mimeType].
  Future<void> openDownloadFile(String filePath, String mimeType) =>
      downloadEngine.openFile(filePath, mimeType);

  // -- Navigation & Security API --------------------------------------------

  /// Accepts a previously-reported SSL error for the given [url].
  Future<void> acceptSslError(String url) =>
      navigationEngine.acceptSslError(viewId, url);

  /// Denies a previously-reported SSL error for the given [url].
  Future<void> denySslError(String url) =>
      navigationEngine.denySslError(viewId, url);

  /// Provide credentials for an HTTP authentication challenge.
  Future<void> httpAuthResponse({
    required int requestId,
    required String username,
    required String password,
  }) =>
      navigationEngine.httpAuthResponse(viewId,
          requestId: requestId, username: username, password: password);

  /// Cancel an HTTP authentication challenge.
  Future<void> cancelHttpAuth(int requestId) =>
      navigationEngine.cancelHttpAuth(viewId, requestId);

  /// Registers URL [schemes] (e.g. `tel`, `mailto`) that should be handled
  /// externally by the OS.
  void registerExternalSchemes(List<String> schemes) =>
      navigationEngine.registerExternalSchemes(schemes);

  /// Registers a navigation rule that matches URLs via [regex] and routes them
  /// to the given [route] handler within the navigation engine.
  void registerNavigationRule(String regex, String route) =>
      navigationEngine.urlRules.addRule(regex, route);

  /// Set a handler for deep links. Return true to consume the navigation.
  void setDeepLinkHandler(DeepLinkHandler? handler) =>
      navigationEngine.setDeepLinkHandler(handler);

  /// Update security configuration at runtime.
  Future<void> updateSecurityConfig({
    int? mixedContentMode,
    bool? safeBrowsingEnabled,
    bool? zoomEnabled,
  }) =>
      navigationEngine.updateSecurityConfig(viewId,
          mixedContentMode: mixedContentMode,
          safeBrowsingEnabled: safeBrowsingEnabled,
          zoomEnabled: zoomEnabled);

  // -- Permissions API ------------------------------------------------------

  /// Returns the current status of a permission type.
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    return FixitPermissionManager().checkPermission(type);
  }

  /// Requests a permission from the OS. Returns the resulting status.
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    return FixitPermissionManager().requestPermission(type);
  }

  /// Registry tracking which native features have been requested/enabled.
  NativeFeatureRegistry get featureRegistry =>
      FixitPermissionManager().featureRegistry;

  /// @internal -- Returns a point-in-time snapshot for the benchmark tool.
  FixitDiagnostics get diagnostics => FixitDiagnostics(
        runtimeInfo: _runtime.info,
        currentUrl: _currentUrl.value ?? '',
        progress: _progress.value,
        isLoading: _loading.value,
        cacheSize: 0,
        cookies: [],
        memoryUsage: 0,
        fps: 60.0,
        errors: [],
      );

  /// Called automatically when the OS reports memory pressure.
  void _handleMemoryPressure(MemoryPressureLevel level) {
    if (level == MemoryPressureLevel.critical) {
      clearCache();
      _runtime.context.logger
          .warning('Critical memory pressure --- clearing caches');
    }
  }

  /// Programmatic refresh for pull-to-refresh.
  Future<void> refresh() async {
    await _runtime.reload();
  }

  // -- Lifecycle Management ------------------------------------------------

  /// Pause the WebView: suspends JS timers, pauses media, flushes cookies.
  Future<void> pause() => _runtime.lifecycle.pause();

  /// Resume the WebView: restarts JS timers, resumes media, restores focus.
  Future<void> resume() => _runtime.lifecycle.resume();

  void dispose() {
    fixitStartupRegistry.clear(viewId);
    _uploadRequestedController.close();
    _diagnosticsController.close();
    _crashController.close();
    _restartController.close();
    navigationEngine.dispose();
    downloadEngine.dispose();
    uploadEngine.dispose();
    offlineEngine.dispose();
    _oAuthInterceptor.dispose();
  }
}
