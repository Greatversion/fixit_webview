/// @internal
/// Dart-side T0 registry.
/// Maps viewId → epoch-ms timestamp of when the Flutter widget was inserted.
///
/// Stored as a singleton map so multiple WebView instances can each track
/// their own T0 independently (tabs, split-screen, nested views).
library fixit_webview.internal.startup_registry;

class _FixitStartupRegistry {
  _FixitStartupRegistry._();
  final _t0 = <int, int>{};

  void markT0(int viewId) {
    _t0[viewId] = DateTime.now().millisecondsSinceEpoch;
  }

  int? getT0(int viewId) => _t0[viewId];

  void clear(int viewId) => _t0.remove(viewId);
}

/// Global startup registry.
/// @internal – not exported from fixit_webview.dart.
final fixitStartupRegistry = _FixitStartupRegistry._();
