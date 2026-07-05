import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform_interface/fixit_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/src/main/kotlin/com/fixit/fixit_webview/webview/FixitApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.fixit.fixit_webview.webview'),
  swiftOut: 'ios/Classes/webview/FixitApi.g.swift',
  swiftOptions: SwiftOptions(),
))

class PigeonRuntimeConfig {
  final String initialUrl;
  final bool enablePooling;
  final bool enableCache;
  final bool enableBridge;

  // Phase 1 Settings
  final bool javaScriptEnabled;
  final bool domStorageEnabled;
  final bool allowFileAccess;
  final bool allowContentAccess;
  final bool mediaPlaybackRequiresGesture;
  final String? userAgent;
  final List<String?> navigationWhitelist;
  final List<String?> navigationBlacklist;
  final bool acceptThirdPartyCookies;
  final List<String?> externalSchemes;
  final bool enableOffline;
  final int mixedContentMode;
  final bool safeBrowsingEnabled;
  final bool zoomEnabled;

  PigeonRuntimeConfig({
    required this.initialUrl,
    required this.enablePooling,
    required this.enableCache,
    required this.enableBridge,
    required this.javaScriptEnabled,
    required this.domStorageEnabled,
    required this.allowFileAccess,
    required this.allowContentAccess,
    required this.mediaPlaybackRequiresGesture,
    this.userAgent,
    required this.navigationWhitelist,
    required this.navigationBlacklist,
    required this.acceptThirdPartyCookies,
    required this.externalSchemes,
    required this.enableOffline,
    this.mixedContentMode = 0,
    this.safeBrowsingEnabled = false,
    this.zoomEnabled = true,
  });
}

@HostApi()
abstract class FixitWebViewHostApi {
  void create(int viewId, PigeonRuntimeConfig config);
  void loadUrl(int viewId, String url);
  void loadUrlWithHeaders(int viewId, String url, Map<String?, String?>? headers, String? method, String? body);
  void loadHtmlString(int viewId, String html, String? baseUrl);
  void stopLoading(int viewId);
  String? getTitle(int viewId);
  void goBack(int viewId);
  void goForward(int viewId);
  void reload(int viewId);
  
  void clearCache(int viewId);
  void clearCookies();
  void setCookie(String url, String key, String value);
  @async
  List<String?> getCookies(String url);

  void httpAuthResponse(int viewId, int requestId, String username, String password);
  void cancelHttpAuth(int viewId, int requestId);

  void updateSecurityConfig(int viewId, int? mixedContentMode, bool? safeBrowsingEnabled, bool? zoomEnabled);

  void evaluateJavascript(int viewId, String javascript);
  
  @async
  String? runJavascriptReturningResult(int viewId, String javascript);

  void postBridgeMessage(int viewId, String message);
  
  void dispose(int viewId);
}
