import 'package:flutter/widgets.dart';
import 'fixit_capabilities.dart';
import 'fixit_theme_config.dart';
import '../internal/diagnostics_models.dart';

class FixitRuntimeConfig {
  final String initialUrl;
  final FixitCapabilities capabilities;
  final String? cacheDirectory;
  final String? userAgent;

  // Phase 1 Core Settings
  final bool javaScriptEnabled;
  final bool domStorageEnabled;
  final bool cacheEnabled;
  final bool allowFileAccess;
  final bool allowContentAccess;
  final bool mediaPlaybackRequiresGesture;
  final bool acceptThirdPartyCookies;
  final int maxUploadFileSize;
  final List<String> allowedUploadMimeTypes;
  final List<String> navigationWhitelist;
  final List<String> navigationBlacklist;
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

  static FixitRuntimeConfigBuilder builder() => FixitRuntimeConfigBuilder();
}

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

  FixitRuntimeConfigBuilder setInitialUrl(String url) {
    _initialUrl = url;
    return this;
  }

  FixitRuntimeConfigBuilder enablePooling() {
    _capabilities.add(FixitCapability.pooling);
    return this;
  }

  FixitRuntimeConfigBuilder enableBridge() {
    _capabilities.add(FixitCapability.bridge);
    return this;
  }

  FixitRuntimeConfigBuilder enableDownloads() {
    _capabilities.add(FixitCapability.downloads);
    return this;
  }

  FixitRuntimeConfigBuilder enableOffline() {
    _capabilities.add(FixitCapability.offline);
    return this;
  }

  // ── Phase 1 Core Settings ──────────────────────────────────────────

  FixitRuntimeConfigBuilder setJavaScriptEnabled(bool enabled) {
    _javaScriptEnabled = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setDomStorageEnabled(bool enabled) {
    _domStorageEnabled = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setCacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setAllowFileAccess(bool enabled) {
    _allowFileAccess = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setAllowContentAccess(bool enabled) {
    _allowContentAccess = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setMediaPlaybackRequiresGesture(bool requires) {
    _mediaPlaybackRequiresGesture = requires;
    return this;
  }

  FixitRuntimeConfigBuilder setAcceptThirdPartyCookies(bool enabled) {
    _acceptThirdPartyCookies = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setMaxUploadFileSize(int bytes) {
    _maxUploadFileSize = bytes;
    return this;
  }

  FixitRuntimeConfigBuilder setAllowedUploadMimeTypes(List<String> mimeTypes) {
    _allowedUploadMimeTypes
      ..clear()
      ..addAll(mimeTypes);
    return this;
  }

  FixitRuntimeConfigBuilder addNavigationWhitelist(List<String> rules) {
    _navigationWhitelist.addAll(rules);
    return this;
  }

  FixitRuntimeConfigBuilder addNavigationBlacklist(List<String> rules) {
    _navigationBlacklist.addAll(rules);
    return this;
  }

  FixitRuntimeConfigBuilder setExternalSchemes(List<String> schemes) {
    _externalSchemes
      ..clear()
      ..addAll(schemes);
    return this;
  }

  // ───────────────────────────────────────────────────────────────────

  FixitRuntimeConfigBuilder enableDiagnostics({
    DiagnosticsLevel level = DiagnosticsLevel.startup,
  }) {
    _diagnosticsLevel = level;
    return this;
  }

  FixitRuntimeConfigBuilder setCacheDirectory(String dir) {
    _cacheDirectory = dir;
    return this;
  }

  FixitRuntimeConfigBuilder setUserAgent(String ua) {
    _userAgent = ua;
    return this;
  }

  FixitRuntimeConfigBuilder setDownloadDirectory(String dir) {
    _downloadDirectory = dir;
    return this;
  }

  FixitRuntimeConfigBuilder setAutoOpenDownload(bool autoOpen) {
    _autoOpenDownload = autoOpen;
    return this;
  }

  FixitRuntimeConfigBuilder setShowDownloadNotifications(bool show) {
    _showDownloadNotifications = show;
    return this;
  }

  FixitRuntimeConfigBuilder setThemeConfig(FixitThemeConfig config) {
    _themeConfig = config;
    return this;
  }

  FixitRuntimeConfigBuilder setSafeBrowsingEnabled(bool enabled) {
    _safeBrowsingEnabled = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder setMixedContentMode(int mode) {
    _mixedContentMode = mode;
    return this;
  }

  FixitRuntimeConfigBuilder setZoomEnabled(bool enabled) {
    _zoomEnabled = enabled;
    return this;
  }

  FixitRuntimeConfigBuilder enablePullToRefresh(
      {Future<void> Function()? onRefresh}) {
    _enablePullToRefresh = true;
    return this;
  }

  FixitRuntimeConfigBuilder setSplashTransitionDuration(Duration duration) {
    _splashTransitionDuration = duration;
    return this;
  }

  FixitRuntimeConfigBuilder enableWhiteFlashPrevention(
      {WidgetBuilder? splashBuilder}) {
    _whiteFlashPrevention = true;
    _splashBuilder = splashBuilder;
    return this;
  }

  FixitRuntimeConfigBuilder enableCustomLoader({
    Widget Function(BuildContext, double)? loaderBuilder,
  }) {
    _loaderBuilder = loaderBuilder;
    return this;
  }

  FixitRuntimeConfigBuilder enableCrashRecovery({
    WidgetBuilder? crashOverlayBuilder,
  }) {
    _enableCrashRecovery = true;
    _crashOverlayBuilder = crashOverlayBuilder;
    return this;
  }

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
