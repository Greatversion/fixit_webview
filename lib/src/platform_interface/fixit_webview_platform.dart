import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../config/fixit_runtime_config.dart';
import 'pigeon_platform_impl.dart';

abstract class FixitWebViewPlatform extends PlatformInterface {
  FixitWebViewPlatform() : super(token: _token);

  static const Object _token = Object();

  static FixitWebViewPlatform _instance = PigeonFixitWebViewPlatform();

  static FixitWebViewPlatform get instance => _instance;

  static set instance(FixitWebViewPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  Future<void> create(int viewId, FixitRuntimeConfig config);
  Future<void> loadUrl(int viewId, String url);
  Future<void> loadUrlWithHeaders(int viewId, String url,
      Map<String, String>? headers, String? method, String? body);
  Future<void> loadHtmlString(int viewId, String html, String? baseUrl);
  Future<void> stopLoading(int viewId);
  Future<String?> getTitle(int viewId);
  Future<void> goBack(int viewId);
  Future<void> goForward(int viewId);
  Future<void> reload(int viewId);

  Future<void> clearCache(int viewId);
  Future<void> clearCookies();
  Future<void> setCookie(String url, String key, String value);
  Future<List<String>> getCookies(String url);

  Future<void> httpAuthResponse(
      int viewId, int requestId, String username, String password);
  Future<void> cancelHttpAuth(int viewId, int requestId);
  Future<void> updateSecurityConfig(int viewId, int? mixedContentMode,
      bool? safeBrowsingEnabled, bool? zoomEnabled);

  Future<void> evaluateJavascript(int viewId, String javascript);
  Future<String?> runJavascriptReturningResult(int viewId, String javascript);

  Future<void> postBridgeMessage(int viewId, String message);

  Future<void> dispose(int viewId);
}
