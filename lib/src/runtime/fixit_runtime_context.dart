import 'package:fixit_core/fixit_core.dart';
import '../cache/fixit_cache_manager.dart';
import '../cookie/fixit_cookie_manager.dart';
import '../cookie/fixit_session_manager.dart';

/// Aggregates shared services (logging, caching, cookies, session, events)
/// that are provided to a [FixitRuntime].
class FixitRuntimeContext {
  /// Logger instance for runtime diagnostics.
  final FixitLogger logger;

  /// Cache manager for clearing WebView caches.
  final FixitCacheManager cache;

  /// Cookie manager for reading and writing HTTP cookies.
  final FixitCookieManager cookies;

  /// Session manager for persisting key-value session data.
  final FixitSessionManager session;

  /// Event bus for publishing and subscribing to internal events.
  final FixitEventBus events;

  /// Creates a [FixitRuntimeContext] with all required services.
  FixitRuntimeContext({
    required this.logger,
    required this.cache,
    required this.cookies,
    required this.session,
    required this.events,
  });
}
