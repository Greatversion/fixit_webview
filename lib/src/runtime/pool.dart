import 'package:fixit_core/fixit_core.dart';
import 'fixit_runtime.dart';
import 'fixit_runtime_context.dart';

class FixitWebViewPool {
  final FixitRuntimeContext context;
  final List<FixitRuntime> _availablePool = [];
  final FixitLogger _logger;

  FixitWebViewPool({required this.context})
      : _logger = FixitLogger(label: 'WebViewPool');

  void prewarm(int viewId) {
    _logger.debug('Pre-warming WebView instance with ID: $viewId');
    final runtime = FixitRuntime.create(viewId, context);
    _availablePool.add(runtime);
  }

  FixitRuntime? get(int viewId) {
    _logger.debug(
        'Attempting to fetch pre-warmed WebView from pool for ID: $viewId');
    for (int i = 0; i < _availablePool.length; i++) {
      if (_availablePool[i].viewId == viewId) {
        return _availablePool.removeAt(i);
      }
    }
    return null;
  }

  void release(FixitRuntime runtime) {
    _logger.debug(
        'Releasing WebView instance with ID: ${runtime.viewId} back to pool');
    _availablePool.add(runtime);
  }
}
