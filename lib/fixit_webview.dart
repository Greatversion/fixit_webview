/// Fixit WebView — production-grade Flutter WebView plugin with JS bridge,
/// native Dart module integration, offline engine, theme engine, and
/// enterprise-grade navigation controls.
library fixit_webview;

export 'src/widgets/fixit_web_view.dart';
export 'src/controller/fixit_web_view_controller.dart';
export 'src/config/fixit_runtime_config.dart';
export 'src/config/fixit_capabilities.dart';
export 'src/cookie/fixit_cookie_manager.dart';
export 'src/cookie/fixit_session_manager.dart';
export 'src/navigation/oauth_interceptor.dart';
export 'src/runtime/fixit_runtime.dart';
export 'src/runtime/fixit_runtime_context.dart';
export 'src/runtime/fixit_runtime_info.dart';
export 'src/cache/fixit_cache_manager.dart';
export 'src/bridge/bridge_handler.dart';
export 'src/bridge/bridge_message.dart';
export 'src/bridge/bridge_manager.dart';
export 'src/bridge/bridge_registry.dart';
export 'src/bridge/bridge_validator.dart';
export 'src/permissions/permission_manager.dart';
export 'src/upload/upload_engine.dart';
export 'src/download/download_engine.dart';
export 'src/navigation/navigation_engine.dart';
export 'src/navigation/url_rules_engine.dart';
export 'src/offline/offline_engine.dart';
export 'src/theme/theme_definition.dart';
export 'src/theme/theme_engine.dart';
export 'src/config/fixit_theme_config.dart';
export 'src/config/ai_adapter.dart';
export 'src/config/native_feature_registry.dart';
export 'src/update/force_update.dart';
export 'src/navigation/interceptors.dart';
export 'src/performance/performance_engine.dart';
export 'src/widgets/fixit_web_view.dart' show FixitWebView;
export 'src/controller/fixit_web_view_controller.dart'
    show WebViewCrashEvent, MemoryPressureLevel;
// NOTE: diagnostics.dart and internal/ are intentionally NOT exported here.
// Diagnostic models are implementation details, not public API commitments.
