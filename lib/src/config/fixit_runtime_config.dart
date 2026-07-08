import 'package:flutter/widgets.dart';
import 'fixit_capabilities.dart';
import 'fixit_theme_config.dart';
import '../internal/diagnostics_models.dart';

/// Holds the full runtime configuration for a [FixitRuntime] instance.
///
/// Use [FixitRuntimeConfig.builder] to construct an instance via the fluent
/// [FixitRuntimeConfigBuilder] API.
class FixitRuntimeConfig {
  /// The initial URL loaded when the WebView first starts.
  final String initialUrl;

  /// The set of [FixitCapability] values active for this runtime.
  final FixitCapabilities capabilities;

  /// Optional custom directory for HTTP cache storage. `null` uses system default.
  final String? cacheDirectory;

  /// Optional custom user agent string. `null` uses the WebView's default.
  final String? userAgent;

  // Phase 1 Core Settings

  /// Whether JavaScript execution is enabled in the WebView.
  final bool javaScriptEnabled;

  /// Whether the DOM storage API is enabled.
  final bool domStorageEnabled;

  /// Whether the HTTP cache is enabled.
  final bool cacheEnabled;

  /// Whether the WebView allows access to file:// URLs.
  final bool allowFileAccess;

  /// Whether the WebView allows access to content:// URLs.
  final bool allowContentAccess;

  /// Whether media playback requires a user gesture to start.
  final bool mediaPlaybackRequiresGesture;

  /// Whether third-party cookies are accepted.
  final bool acceptThirdPartyCookies;

  /// Maximum allowed file upload size in bytes. Defaults to 50 MB.
  final int maxUploadFileSize;

  /// List of MIME types permitted in file upload dialogs.
  final List<String> allowedUploadMimeTypes;

  /// List of URL patterns allowed for navigation.
  final List<String> navigationWhitelist;

  /// List of URL patterns blocked from navigation.
  final List<String> navigationBlacklist;

  /// List of URL schemes (e.g. "tel", "mailto") handled by external apps.
  final List<String> externalSchemes;

  /// Diagnostics level. `null` means diagnostics are fully disabled (default).
  final DiagnosticsLevel? diagnosticsLevel;

  /// Convenience getter. True when any diagnostics level is active.
  bool get diagnosticsEnabled => diagnosticsLevel != null;

  /// Download destination directory. `null` uses OS default (Downloads).
  final String? downloadDirectory;

  /// Whether to auto-open downloaded files with the system handler.
  final bool autoOpenDownload;

  /// Whether to show system notifications for download completion.
  final bool showDownloadNotifications;

  /// Theme configuration for auto-generated CSS themes.
  final FixitThemeConfig? themeConfig;

  /// Whether to enable safe browsing (Android) or block dangerous content.
  final bool safeBrowsingEnabled;

  /// Mixed content mode: 0 = never, 1 = compatibility, 2 = always.
  final int mixedContentMode;

  /// Whether pinch-to-zoom and zoom controls are enabled.
  final bool zoomEnabled;

  /// Whether pull-to-refresh gesture is enabled.
  final bool enablePullToRefresh;

  /// Whether white flash prevention is enabled (splash → invisible WebView → fade in).
  final bool whiteFlashPrevention;

  /// Whether to automatically recreate the WebView after a renderer crash.
  final bool enableCrashRecovery;

  /// Optional builder for a custom overlay shown while recovering from a crash.
  /// Defaults to a centered message with a retry button.
  final WidgetBuilder? crashOverlayBuilder;

  /// Optional builder for a custom splash widget shown before first paint.
  final WidgetBuilder? splashBuilder;

  /// Duration of the splash → WebView fade transition.
  /// Defaults to 300ms. Only applies when [whiteFlashPrevention] is enabled.
  final Duration splashTransitionDuration;

  /// Optional builder for a custom loading overlay shown during page navigation.
  /// Receives the build context and current progress (0.0–1.0).
  final Widget Function(BuildContext, double)? loaderBuilder;

  FixitRuntimeConfig._({
    required this.initialUrl,
    required this.capabilities,
    required this.diagnosticsLevel,
    required this.javaScriptEnabled,
    required this.domStorageEnabled,
    required this.cacheEnabled,
    required this.allowFileAccess,
    required this.allowContentAccess,
    required this.mediaPlaybackRequiresGesture,
    required this.acceptThirdPartyCookies,
    required this.maxUploadFileSize,
    required this.allowedUploadMimeTypes,
    required this.navigationWhitelist,
    required this.navigationBlacklist,
    required this.externalSchemes,
    this.cacheDirectory,
    this.userAgent,
    this.downloadDirectory,
    this.autoOpenDownload = false,
    this.showDownloadNotifications = true,
    this.themeConfig,
    this.safeBrowsingEnabled = false,
    this.mixedContentMode = 0,
    this.zoomEnabled = true,
    this.enablePullToRefresh = false,
    this.whiteFlashPrevention = false,
    this.enableCrashRecovery = false,
    this.crashOverlayBuilder,
    this.splashBuilder,
    this.splashTransitionDuration = const Duration(milliseconds: 300),
    this.loaderBuilder,
  });

  /// Returns a new [FixitRuntimeConfigBuilder] for fluently constructing a
  /// [FixitRuntimeConfig].
  static FixitRuntimeConfigBuilder builder() => FixitRuntimeConfigBuilder();
}

/// A fluent builder for constructing a [FixitRuntimeConfig] instance.
///
/// Call [build] after configuring all desired properties to produce the final
/// immutable configuration object.
class FixitRuntimeConfigBuilder {
  String _initialUrl = 'about:blank';
  final Set<FixitCapability> _capabilities = {};
  String? _cacheDirectory;
  String? _userAgent;
  String? _downloadDirectory;
  bool _autoOpenDownload = false;
  bool _showDownloadNotifications = true;
  DiagnosticsLevel? _diagnosticsLevel;
  FixitThemeConfig? _themeConfig;
  bool _safeBrowsingEnabled = false;
  int _mixedContentMode = 0;
  bool _zoomEnabled = true;
  bool _enablePullToRefresh = false;
  bool _whiteFlashPrevention = false;
  bool _enableCrashRecovery = false;
  WidgetBuilder? _crashOverlayBuilder;
  WidgetBuilder? _splashBuilder;
  Duration _splashTransitionDuration = const Duration(milliseconds: 300);
  Widget Function(BuildContext, double)? _loaderBuilder;

  bool _javaScriptEnabled = true;
  bool _domStorageEnabled = true;
  bool _cacheEnabled = true;
  bool _allowFileAccess = false;
  bool _allowContentAccess = false;
  bool _mediaPlaybackRequiresGesture = true;
  bool _acceptThirdPartyCookies = false;
  int _maxUploadFileSize = 50 * 1024 * 1024; // 50 MB
  final List<String> _allowedUploadMimeTypes = [];
  final List<String> _navigationWhitelist = [];
  final List<String> _navigationBlacklist = [];
  final List<String> _externalSchemes = [];

  /// Sets the initial URL loaded when the WebView starts.
  FixitRuntimeConfigBuilder setInitialUrl(String url) {
    _initialUrl = url;
    return this;
  }

  /// Enables HTTP connection pooling for reduced network latency.
  FixitRuntimeConfigBuilder enablePooling() {
    _capabilities.add(FixitCapability.pooling);
    return this;
  }

  /// Enables the JavaScript-to-native bridge communication layer.
  FixitRuntimeConfigBuilder enableBridge() {
    _capabilities.add(FixitCapability.bridge);
    return this;
  }

  /// Enables file download support from the WebView.
  FixitRuntimeConfigBuilder enableDownloads() {
    _capabilities.add(FixitCapability.downloads);
    return this;
  }

  /// Enables offline caching and connectivity-aware fallback behavior.
  FixitRuntimeConfigBuilder enableOffline() {
    _capabilities.add(FixitCapability.offline);
    return this;
  }

  // ── Phase 1 Core Settings ──────────────────────────────────────────

  /// Sets whether JavaScript execution is enabled.
  FixitRuntimeConfigBuilder setJavaScriptEnabled(bool enabled) {
    _javaScriptEnabled = enabled;
    return this;
  }

  /// Sets whether the DOM storage API is enabled.
  FixitRuntimeConfigBuilder setDomStorageEnabled(bool enabled) {
    _domStorageEnabled = enabled;
    return this;
  }

  /// Sets whether the HTTP cache is enabled.
  FixitRuntimeConfigBuilder setCacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
    return this;
  }

  /// Sets whether the WebView may access file:// URLs.
  FixitRuntimeConfigBuilder setAllowFileAccess(bool enabled) {
    _allowFileAccess = enabled;
    return this;
  }

  /// Sets whether the WebView may access content:// URLs.
  FixitRuntimeConfigBuilder setAllowContentAccess(bool enabled) {
    _allowContentAccess = enabled;
    return this;
  }

  /// Sets whether media playback requires a user gesture to start.
  FixitRuntimeConfigBuilder setMediaPlaybackRequiresGesture(bool requires) {
    _mediaPlaybackRequiresGesture = requires;
    return this;
  }

  /// Sets whether third-party cookies are accepted.
  FixitRuntimeConfigBuilder setAcceptThirdPartyCookies(bool enabled) {
    _acceptThirdPartyCookies = enabled;
    return this;
  }

  /// Sets the maximum allowed file upload size in [bytes].
  FixitRuntimeConfigBuilder setMaxUploadFileSize(int bytes) {
    _maxUploadFileSize = bytes;
    return this;
  }

  /// Replaces the list of allowed MIME types for file upload with [mimeTypes].
  FixitRuntimeConfigBuilder setAllowedUploadMimeTypes(List<String> mimeTypes) {
    _allowedUploadMimeTypes
      ..clear()
      ..addAll(mimeTypes);
    return this;
  }

  /// Adds [rules] to the navigation whitelist.
  FixitRuntimeConfigBuilder addNavigationWhitelist(List<String> rules) {
    _navigationWhitelist.addAll(rules);
    return this;
  }

  /// Adds [rules] to the navigation blacklist.
  FixitRuntimeConfigBuilder addNavigationBlacklist(List<String> rules) {
    _navigationBlacklist.addAll(rules);
    return this;
  }

  /// Replaces the list of externally handled URL schemes with [schemes].
  FixitRuntimeConfigBuilder setExternalSchemes(List<String> schemes) {
    _externalSchemes
      ..clear()
      ..addAll(schemes);
    return this;
  }

  // ───────────────────────────────────────────────────────────────────

  /// Enables diagnostic logging at the given [level].
  FixitRuntimeConfigBuilder enableDiagnostics({
    DiagnosticsLevel level = DiagnosticsLevel.startup,
  }) {
    _diagnosticsLevel = level;
    return this;
  }

  /// Sets a custom directory [dir] for HTTP cache storage.
  FixitRuntimeConfigBuilder setCacheDirectory(String dir) {
    _cacheDirectory = dir;
    return this;
  }

  /// Overrides the WebView's default user agent with [ua].
  FixitRuntimeConfigBuilder setUserAgent(String ua) {
    _userAgent = ua;
    return this;
  }

  /// Sets a custom download destination directory.
  /// `null` (default) uses the OS default Downloads folder.
  FixitRuntimeConfigBuilder setDownloadDirectory(String dir) {
    _downloadDirectory = dir;
    return this;
  }

  /// Sets whether downloaded files should auto-open with the system handler.
  FixitRuntimeConfigBuilder setAutoOpenDownload(bool autoOpen) {
    _autoOpenDownload = autoOpen;
    return this;
  }

  /// Sets whether to show system notifications for completed downloads.
  FixitRuntimeConfigBuilder setShowDownloadNotifications(bool show) {
    _showDownloadNotifications = show;
    return this;
  }

  /// Attaches a [FixitThemeConfig] for auto-generated CSS theme injection.
  FixitRuntimeConfigBuilder setThemeConfig(FixitThemeConfig config) {
    _themeConfig = config;
    return this;
  }

  /// Enables safe browsing (Android) to block dangerous or malicious content.
  FixitRuntimeConfigBuilder setSafeBrowsingEnabled(bool enabled) {
    _safeBrowsingEnabled = enabled;
    return this;
  }

  /// Sets the mixed content mode: 0 = never allow, 1 = compatibility, 2 = always allow.
  FixitRuntimeConfigBuilder setMixedContentMode(int mode) {
    _mixedContentMode = mode;
    return this;
  }

  /// Sets whether pinch-to-zoom and zoom controls are enabled.
  FixitRuntimeConfigBuilder setZoomEnabled(bool enabled) {
    _zoomEnabled = enabled;
    return this;
  }

  /// Enables the pull-to-refresh gesture on the WebView.
  FixitRuntimeConfigBuilder enablePullToRefresh(
      {Future<void> Function()? onRefresh}) {
    _enablePullToRefresh = true;
    return this;
  }

  /// Sets the duration of the splash-to-WebView fade transition.
  /// Defaults to 300 ms. Only applies when [enableWhiteFlashPrevention] is active.
  FixitRuntimeConfigBuilder setSplashTransitionDuration(Duration duration) {
    _splashTransitionDuration = duration;
    return this;
  }

  /// Enables white flash prevention by showing a splash widget until the
  /// WebView is ready, then fading to the WebView content.
  FixitRuntimeConfigBuilder enableWhiteFlashPrevention(
      {WidgetBuilder? splashBuilder}) {
    _whiteFlashPrevention = true;
    _splashBuilder = splashBuilder;
    return this;
  }

  /// Enables a custom loading overlay shown during page navigation.
  /// The [loaderBuilder] receives the build context and a progress value (0.0–1.0).
  FixitRuntimeConfigBuilder enableCustomLoader({
    Widget Function(BuildContext, double)? loaderBuilder,
  }) {
    _loaderBuilder = loaderBuilder;
    return this;
  }

  /// Enables automatic recreation of the WebView after a renderer crash,
  /// with an optional custom overlay shown during recovery.
  FixitRuntimeConfigBuilder enableCrashRecovery({
    WidgetBuilder? crashOverlayBuilder,
  }) {
    _enableCrashRecovery = true;
    _crashOverlayBuilder = crashOverlayBuilder;
    return this;
  }

  /// Builds and returns the [FixitRuntimeConfig] with all configured values.
  FixitRuntimeConfig build() {
    return FixitRuntimeConfig._(
      initialUrl: _initialUrl,
      capabilities: FixitCapabilities(activeCapabilities: _capabilities),
      diagnosticsLevel: _diagnosticsLevel,
      javaScriptEnabled: _javaScriptEnabled,
      domStorageEnabled: _domStorageEnabled,
      cacheEnabled: _cacheEnabled,
      allowFileAccess: _allowFileAccess,
      allowContentAccess: _allowContentAccess,
      mediaPlaybackRequiresGesture: _mediaPlaybackRequiresGesture,
      acceptThirdPartyCookies: _acceptThirdPartyCookies,
      maxUploadFileSize: _maxUploadFileSize,
      allowedUploadMimeTypes: List.unmodifiable(_allowedUploadMimeTypes),
      navigationWhitelist: List.unmodifiable(_navigationWhitelist),
      navigationBlacklist: List.unmodifiable(_navigationBlacklist),
      externalSchemes: List.unmodifiable(_externalSchemes),
      cacheDirectory: _cacheDirectory,
      userAgent: _userAgent,
      downloadDirectory: _downloadDirectory,
      autoOpenDownload: _autoOpenDownload,
      showDownloadNotifications: _showDownloadNotifications,
      themeConfig: _themeConfig,
      safeBrowsingEnabled: _safeBrowsingEnabled,
      mixedContentMode: _mixedContentMode,
      zoomEnabled: _zoomEnabled,
      enablePullToRefresh: _enablePullToRefresh,
      whiteFlashPrevention: _whiteFlashPrevention,
      enableCrashRecovery: _enableCrashRecovery,
      crashOverlayBuilder: _crashOverlayBuilder,
      splashBuilder: _splashBuilder,
      splashTransitionDuration: _splashTransitionDuration,
      loaderBuilder: _loaderBuilder,
    );
  }
}
