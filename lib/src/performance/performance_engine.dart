import 'package:fixit_core/fixit_core.dart';
import '../runtime/fixit_runtime_info.dart';

/// A snapshot of performance metrics collected from the WebView.
class FixitPerformanceMetrics {
  /// The current frames per second.
  final double fps;

  /// The current memory usage in bytes.
  final int memoryBytes;

  /// The current CPU usage as a percentage.
  final double cpuPercent;

  /// The time taken to load the current page.
  final Duration loadTime;

  /// Creates a [FixitPerformanceMetrics] snapshot with the given values.
  FixitPerformanceMetrics({
    required this.fps,
    required this.memoryBytes,
    required this.cpuPercent,
    required this.loadTime,
  });
}

/// Records and reports performance data (load times, FPS, memory, CPU) for
/// a [FixitRuntime] using the logging infrastructure.
class FixitPerformanceEngine {
  final FixitLogger _logger = FixitLogger(label: 'PerformanceEngine');

  /// The runtime info associated with this performance engine.
  final FixitRuntimeInfo runtimeInfo;

  /// Creates a [FixitPerformanceEngine] for the given [runtimeInfo].
  FixitPerformanceEngine({required this.runtimeInfo});

  /// Records the page load [duration] via the performance logger.
  void recordLoadTime(Duration duration) {
    _logger.performance(
        'Page loaded in ${duration.inMilliseconds}ms for runtime ${runtimeInfo.runtimeId}');
  }

  /// Records a snapshot of [metrics] via the performance logger.
  void recordMetrics(FixitPerformanceMetrics metrics) {
    _logger.performance(
        'Metrics snapshot - FPS: ${metrics.fps}, Memory: ${metrics.memoryBytes} bytes, CPU: ${metrics.cpuPercent}%');
  }
}
