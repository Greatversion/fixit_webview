import 'dart:async';

/// Represents the result of an OAuth callback URL detected during navigation.
class OAuthCallback {
  /// The original callback URL that was intercepted.
  final String rawUrl;

  /// The OAuth authorization code, if present.
  final String? code;

  /// The OAuth access token, if present.
  final String? accessToken;

  /// The OpenID Connect ID token, if present.
  final String? idToken;

  /// The OAuth state parameter for CSRF validation.
  final String? state;

  /// The OAuth error description, if present.
  final String? error;

  /// All query and fragment parameters extracted from the callback URL.
  final Map<String, String> allParams;

  OAuthCallback({
    required this.rawUrl,
    this.code,
    this.accessToken,
    this.idToken,
    this.state,
    this.error,
    required this.allParams,
  });
}

/// Intercepts WebView navigation to detect OAuth callback URLs and emit
/// structured [OAuthCallback] events via a stream.
class FixitOAuthInterceptor {
  final List<String> _callbackPatterns = [];
  final _controller = StreamController<OAuthCallback>.broadcast();

  /// A broadcast stream that emits [OAuthCallback] when a matching URL is detected.
  Stream<OAuthCallback> get onOAuthCallback => _controller.stream;

  /// Adds a URL pattern to watch for OAuth callbacks.
  /// URLs containing [pattern] will be analyzed when [analyze] is called.
  void addCallbackPattern(String pattern) {
    if (!_callbackPatterns.contains(pattern)) {
      _callbackPatterns.add(pattern);
    }
  }

  /// Removes a previously registered callback pattern.
  void removeCallbackPattern(String pattern) {
    _callbackPatterns.remove(pattern);
  }

  /// Removes all registered callback patterns.
  void clearPatterns() => _callbackPatterns.clear();

  /// Whether any callback patterns have been registered.
  bool get hasPatterns => _callbackPatterns.isNotEmpty;

  /// Analyzes a URL for OAuth callback parameters.
  /// Returns `true` if the URL matched a registered pattern and an
  /// [OAuthCallback] was dispatched to the stream.
  bool analyze(String url) {
    if (_callbackPatterns.isEmpty) return false;

    final matchesPattern = _callbackPatterns.any((p) => url.contains(p));
    if (!matchesPattern) return false;

    try {
      final uri = Uri.parse(url);
      final allParams = <String, String>{};

      allParams.addAll(uri.queryParameters);

      if (uri.fragment.isNotEmpty) {
        for (final pair in uri.fragment.split('&')) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            allParams[Uri.decodeComponent(parts[0])] =
                Uri.decodeComponent(parts[1]);
          }
        }
      }

      if (allParams.isEmpty) return false;

      final callback = OAuthCallback(
        rawUrl: url,
        code: allParams['code'],
        accessToken: allParams['access_token'],
        idToken: allParams['id_token'],
        state: allParams['state'],
        error: allParams['error'],
        allParams: allParams,
      );

      _controller.add(callback);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Closes the stream controller and releases resources.
  void dispose() {
    _controller.close();
  }
}
