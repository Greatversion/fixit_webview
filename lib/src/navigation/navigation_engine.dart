import 'dart:async';
import 'package:flutter/services.dart';
import 'url_rules_engine.dart';

/// Represents a navigation attempt from the WebView.
class NavigationRequest {
  /// The URL being navigated to.
  final String url;

  /// Whether this navigation occurs in the main frame.
  final bool isMainFrame;

  /// Whether this navigation is a server-side redirect.
  final bool isRedirect;

  /// The type of navigation (e.g. 'link', 'form', 'other').
  final String navigationType;

  const NavigationRequest({
    required this.url,
    this.isMainFrame = true,
    this.isRedirect = false,
    this.navigationType = 'other',
  });
}

/// Represents an SSL error encountered by the WebView.
class SslErrorEvent {
  /// The URL on which the SSL error occurred.
  final String url;

  /// A description of the SSL error.
  final String error;

  /// The hostname associated with the error, if available.
  final String? host;

  const SslErrorEvent({
    required this.url,
    required this.error,
    this.host,
  });
}

/// A single entry in the navigation history stack.
class NavigationEntry {
  /// The URL visited.
  final String url;

  /// The page title at the time of navigation, if available.
  final String? title;

  /// When this navigation entry was created.
  final DateTime timestamp;

  const NavigationEntry({
    required this.url,
    this.title,
    required this.timestamp,
  });
}

/// Tracks navigation history with back/forward stack navigation.
class NavigationHistory {
  final List<NavigationEntry> _entries = [];
  int _currentIndex = -1;

  /// Entries before the current position (back stack).
  List<NavigationEntry> get backStack =>
      _currentIndex > 0 ? _entries.sublist(0, _currentIndex) : [];

  /// Entries after the current position (forward stack).
  List<NavigationEntry> get forwardStack => _entries.length > _currentIndex + 1
      ? _entries.sublist(_currentIndex + 1)
      : [];

  /// An unmodifiable view of all entries in the history stack.
  List<NavigationEntry> get all => List.unmodifiable(_entries);

  /// The current entry, or `null` if the history is empty.
  NavigationEntry? get current =>
      _currentIndex >= 0 ? _entries[_currentIndex] : null;

  /// Whether there are entries to navigate back to.
  bool get canGoBack => _currentIndex > 0;

  /// Whether there are entries to navigate forward to.
  bool get canGoForward => _currentIndex < _entries.length - 1;

  /// Pushes a new entry onto the stack, clearing any forward history.
  void push(NavigationEntry entry) {
    if (_currentIndex < _entries.length - 1) {
      _entries.removeRange(_currentIndex + 1, _entries.length);
    }
    _entries.add(entry);
    _currentIndex = _entries.length - 1;
  }

  /// Replaces the current history entry with [entry], or pushes it if the
  /// history is empty.
  void replaceCurrent(NavigationEntry entry) {
    if (_currentIndex >= 0 && _currentIndex < _entries.length) {
      _entries[_currentIndex] = entry;
    } else {
      push(entry);
    }
  }

  /// Clears the entire navigation history.
  void clear() {
    _entries.clear();
    _currentIndex = -1;
  }
}

/// Represents an HTTP authentication request from the WebView.
class HttpAuthRequest {
  /// The host requesting authentication.
  final String host;

  /// The authentication realm.
  final String realm;

  /// The port on which the request was made.
  final int port;

  /// A unique identifier for this auth request.
  final int requestId;

  /// Creates an [HttpAuthRequest] with the given properties.
  const HttpAuthRequest({
    required this.host,
    required this.realm,
    this.port = 0,
    this.requestId = 0,
  });
}

/// Represents a navigation that was blocked by the rules engine.
class BlockedNavigation {
  /// The URL that was blocked.
  final String url;

  /// A human-readable reason explaining why the navigation was blocked.
  final String reason;

  /// Creates a [BlockedNavigation] with the given [url] and [reason].
  const BlockedNavigation({required this.url, required this.reason});
}

/// Signature for a deep link handler. Return true to consume the navigation.
typedef DeepLinkHandler = bool Function(String url);

/// Manages navigation interception, SSL error handling, and URL routing.
class FixitNavigationEngine {
  static const _channel = MethodChannel('com.fixit.fixit_webview/navigation');

  final _navigationController = StreamController<NavigationRequest>.broadcast();
  final _sslErrorController = StreamController<SslErrorEvent>.broadcast();
  final _blockedController = StreamController<BlockedNavigation>.broadcast();
  final _httpAuthController = StreamController<HttpAuthRequest>.broadcast();
  final _urlRules = FixitUrlRulesEngine();
  List<String> _externalSchemes = [];
  DeepLinkHandler? _deepLinkHandler;

  /// Navigation history tracking (requires manual feed from url/title events).
  final NavigationHistory history = NavigationHistory();

  /// A broadcast stream that emits when the WebView requests a navigation.
  Stream<NavigationRequest> get onNavigationRequested =>
      _navigationController.stream;

  /// A broadcast stream that emits when an SSL error is encountered.
  Stream<SslErrorEvent> get onSslError => _sslErrorController.stream;

  /// Fired when a navigation is blocked by the rules engine.
  Stream<BlockedNavigation> get onNavigationBlocked =>
      _blockedController.stream;

  /// Fired when the page requests HTTP authentication credentials.
  Stream<HttpAuthRequest> get onHttpAuthRequest => _httpAuthController.stream;

  /// The URL rules engine used to evaluate navigation URLs.
  FixitUrlRulesEngine get urlRules => _urlRules;

  /// Register external URL schemes that should be opened by the OS.
  void registerExternalSchemes(List<String> schemes) {
    _externalSchemes = schemes;
  }

  /// An unmodifiable list of external URL schemes (e.g. 'tel', 'mailto')
  /// that should be opened by the operating system.
  List<String> get externalSchemes => List.unmodifiable(_externalSchemes);

  /// Set a handler for deep links. The handler receives the URL and should
  /// return true if it consumed the navigation (preventing WebView load).
  void setDeepLinkHandler(DeepLinkHandler? handler) {
    _deepLinkHandler = handler;
  }

  /// The currently registered deep link handler, or `null`.
  DeepLinkHandler? get deepLinkHandler => _deepLinkHandler;

  /// Evaluate a URL against the rules engine.
  /// Returns 'allow', 'block', or 'external'.
  String evaluateUrl(String url) {
    final route = _urlRules.match(url);
    if (route != 'block' &&
        _deepLinkHandler != null &&
        _deepLinkHandler!(url)) {
      return 'deepLink';
    }
    return route;
  }

  /// Accept an SSL error and proceed.
  Future<void> acceptSslError(int viewId, String url) async {
    try {
      await _channel.invokeMethod('acceptSslError', {
        'viewId': viewId,
        'url': url,
      });
    } catch (_) {}
  }

  /// Deny/block an SSL error.
  Future<void> denySslError(int viewId, String url) async {
    try {
      await _channel.invokeMethod('denySslError', {
        'viewId': viewId,
        'url': url,
      });
    } catch (_) {}
  }

  /// Provide credentials for an HTTP authentication challenge.
  Future<void> httpAuthResponse(
    int viewId, {
    required int requestId,
    required String username,
    required String password,
  }) async {
    try {
      await _channel.invokeMethod('httpAuthResponse', {
        'viewId': viewId,
        'requestId': requestId,
        'username': username,
        'password': password,
      });
    } catch (_) {}
  }

  /// Cancel an HTTP authentication challenge.
  Future<void> cancelHttpAuth(int viewId, int requestId) async {
    try {
      await _channel.invokeMethod('cancelHttpAuth', {
        'viewId': viewId,
        'requestId': requestId,
      });
    } catch (_) {}
  }

  /// Update security-related configuration at runtime.
  Future<void> updateSecurityConfig(
    int viewId, {
    int? mixedContentMode,
    bool? safeBrowsingEnabled,
    bool? zoomEnabled,
  }) async {
    try {
      await _channel.invokeMethod('updateSecurityConfig', {
        'viewId': viewId,
        if (mixedContentMode != null) 'mixedContentMode': mixedContentMode,
        if (safeBrowsingEnabled != null)
          'safeBrowsingEnabled': safeBrowsingEnabled,
        if (zoomEnabled != null) 'zoomEnabled': zoomEnabled,
      });
    } catch (_) {}
  }

  /// Load a URL with custom HTTP headers and optional POST body.
  Future<void> loadUrlWithHeaders(
    int viewId,
    String url, {
    Map<String, String>? headers,
    String? method,
    String? body,
  }) async {
    try {
      await _channel.invokeMethod('loadUrlWithHeaders', {
        'viewId': viewId,
        'url': url,
        if (headers != null) 'headers': headers,
        if (method != null) 'method': method,
        if (body != null) 'body': body,
      });
    } catch (_) {}
  }

  /// Emits a navigation request event to [onNavigationRequested].
  void handleNavigationRequest(NavigationRequest request) {
    _navigationController.add(request);
  }

  /// Emits an SSL error event to [onSslError].
  void handleSslError(SslErrorEvent event) {
    _sslErrorController.add(event);
  }

  /// Emits a blocked navigation event to [onNavigationBlocked].
  void handleBlockedNavigation(BlockedNavigation event) {
    _blockedController.add(event);
  }

  /// Emits an HTTP authentication request to [onHttpAuthRequest].
  void handleHttpAuthRequest(HttpAuthRequest request) {
    _httpAuthController.add(request);
  }

  /// Releases all stream controllers used by this engine.
  void dispose() {
    _navigationController.close();
    _sslErrorController.close();
    _blockedController.close();
    _httpAuthController.close();
  }
}
