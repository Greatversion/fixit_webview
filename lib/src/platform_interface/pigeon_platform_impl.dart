import '../config/fixit_runtime_config.dart';
import 'fixit_api.g.dart';
import 'fixit_webview_platform.dart';

class PigeonFixitWebViewPlatform extends FixitWebViewPlatform {
  final FixitWebViewHostApi _api = FixitWebViewHostApi();

  @override
  Future<void> create(int viewId, FixitRuntimeConfig config) async {
    final pigeonConfig = PigeonRuntimeConfig(
      initialUrl: config.initialUrl,
      enablePooling: config.capabilities.pooling,
      enableCache: config.capabilities.offline || config.cacheDirectory != null,
      enableBridge: config.capabilities.bridge,
      javaScriptEnabled: config.javaScriptEnabled,
      domStorageEnabled: config.domStorageEnabled,
      allowFileAccess: config.allowFileAccess,
      allowContentAccess: config.allowContentAccess,
      mediaPlaybackRequiresGesture: config.mediaPlaybackRequiresGesture,
      userAgent: config.userAgent,
      navigationWhitelist: config.navigationWhitelist,
      navigationBlacklist: config.navigationBlacklist,
      acceptThirdPartyCookies: config.acceptThirdPartyCookies,
      externalSchemes: config.externalSchemes,
      enableOffline: config.capabilities.offline,
      mixedContentMode: config.mixedContentMode,
      safeBrowsingEnabled: config.safeBrowsingEnabled,
      zoomEnabled: config.zoomEnabled,
    );
    await _api.create(viewId, pigeonConfig);
  }

  @override
  Future<void> loadUrl(int viewId, String url) async {
    await _api.loadUrl(viewId, url);
  }

  @override
  Future<void> loadUrlWithHeaders(int viewId, String url,
      Map<String, String>? headers, String? method, String? body) async {
    await _api.loadUrlWithHeaders(
        viewId, url, headers?.cast<String?, String?>(), method, body);
  }

  @override
  Future<void> loadHtmlString(int viewId, String html, String? baseUrl) async {
    await _api.loadHtmlString(viewId, html, baseUrl);
  }

  @override
  Future<void> stopLoading(int viewId) async {
    await _api.stopLoading(viewId);
  }

  @override
  Future<String?> getTitle(int viewId) async {
    return await _api.getTitle(viewId);
  }

  @override
  Future<void> goBack(int viewId) async {
    await _api.goBack(viewId);
  }

  @override
  Future<void> goForward(int viewId) async {
    await _api.goForward(viewId);
  }

  @override
  Future<void> reload(int viewId) async {
    await _api.reload(viewId);
  }

  @override
  Future<void> clearCache(int viewId) async {
    await _api.clearCache(viewId);
  }

  @override
  Future<void> clearCookies() async {
    await _api.clearCookies();
  }

  @override
  Future<void> setCookie(String url, String key, String value) async {
    await _api.setCookie(url, key, value);
  }

  @override
  Future<List<String>> getCookies(String url) async {
    final cookies = await _api.getCookies(url);
    return cookies.where((c) => c != null).cast<String>().toList();
  }

  @override
  Future<void> httpAuthResponse(
      int viewId, int requestId, String username, String password) async {
    await _api.httpAuthResponse(viewId, requestId, username, password);
  }

  @override
  Future<void> cancelHttpAuth(int viewId, int requestId) async {
    await _api.cancelHttpAuth(viewId, requestId);
  }

  @override
  Future<void> updateSecurityConfig(int viewId, int? mixedContentMode,
      bool? safeBrowsingEnabled, bool? zoomEnabled) async {
    await _api.updateSecurityConfig(
        viewId, mixedContentMode, safeBrowsingEnabled, zoomEnabled);
  }

  @override
  Future<void> evaluateJavascript(int viewId, String javascript) async {
    await _api.evaluateJavascript(viewId, javascript);
  }

  @override
  Future<String?> runJavascriptReturningResult(
      int viewId, String javascript) async {
    return await _api.runJavascriptReturningResult(viewId, javascript);
  }

  @override
  Future<void> postBridgeMessage(int viewId, String message) async {
    await _api.postBridgeMessage(viewId, message);
  }

  @override
  Future<void> dispose(int viewId) async {
    await _api.dispose(viewId);
  }
}
