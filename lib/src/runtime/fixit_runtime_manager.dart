import 'package:fixit_core/fixit_core.dart';
import 'fixit_runtime.dart';
import 'fixit_runtime_context.dart';

class FixitRuntimeManager {
  final FixitRuntimeContext context;
  final Map<int, FixitRuntime> _activeRuntimes = {};
  final FixitLogger _logger;

  FixitRuntimeManager({required this.context})
      : _logger = FixitLogger(label: 'RuntimeManager');

  FixitRuntime getOrCreateRuntime(int viewId) {
    if (_activeRuntimes.containsKey(viewId)) {
      return _activeRuntimes[viewId]!;
    }
    _logger.debug('Creating runtime instance for view ID: $viewId');
    final runtime = FixitRuntime.create(viewId, context);
    _activeRuntimes[viewId] = runtime;
    return runtime;
  }

  void destroyRuntime(int viewId) {
    final runtime = _activeRuntimes.remove(viewId);
    if (runtime != null) {
      _logger.debug('Destroying runtime instance for view ID: $viewId');
      runtime.dispose();
    }
  }
}
