import 'fixit_runtime_info.dart';

/// Represents a single named startup milestone (T0--T5).
/// Used only by the benchmark/diagnostic tool; never surfaced in public API.
class StartupMilestone {
  /// Milestone label e.g. "T1_platform_view_created"
  final String name;

  /// Wall-clock epoch time in milliseconds.
  final int epochMs;

  const StartupMilestone({required this.name, required this.epochMs});

  Map<String, dynamic> toJson() => {'name': name, 'epochMs': epochMs};
}

class FixitDiagnostics {
  final FixitRuntimeInfo runtimeInfo;
  final String? currentUrl;
  final double progress;
  final bool isLoading;
  final int cacheSize;
  final List<String> cookies;
  final int memoryUsage;
  final double fps;
  final List<String> errors;

  /// Startup timeline milestones (T0--T5).
  /// Populated only when enableDiagnostics = true.
  final List<StartupMilestone> startupTimeline;

  FixitDiagnostics({
    required this.runtimeInfo,
    required this.currentUrl,
    required this.progress,
    required this.isLoading,
    required this.cacheSize,
    required this.cookies,
    required this.memoryUsage,
    required this.fps,
    required this.errors,
    this.startupTimeline = const [],
  });

  Map<String, dynamic> toJson() => {
        'runtimeId': runtimeInfo.runtimeId,
        'currentUrl': currentUrl ?? '',
        'progress': progress,
        'isLoading': isLoading,
        'cacheSize': cacheSize,
        'cookies': cookies,
        'memoryUsage': memoryUsage,
        'fps': fps,
        'errors': errors,
        'startupTimeline': startupTimeline.map((m) => m.toJson()).toList(),
      };
}
