/// @internal
/// Everything in this file is internal to the SDK diagnostic subsystem.
/// Do NOT export these types from [fixit_webview.dart].
/// The benchmark tool imports this file directly via a relative or internal import.
library fixit_webview.internal.diagnostics_models;

// -- DiagnosticsLevel ----------------------------------------------------------

/// Controls which categories of diagnostics are collected.
///
/// Levels are additive: [verbose] includes everything from [startup] and [performance].
///
/// **Not part of the public SDK API.** Subject to change without a semver bump.
enum DiagnosticsLevel {
  /// Only collect startup timeline milestones (T0--T5).
  /// Lowest overhead.
  startup,

  /// Collect startup milestones + FPS + memory samples.
  performance,

  /// Collect startup milestones + FPS + memory + JS bridge timings + cache events.
  verbose,
}

// -- StartupMilestone ----------------------------------------------------------

/// A single named startup milestone.
///
/// | name                          | Meaning                                    |
/// |-------------------------------|--------------------------------------------|
/// | T0_flutter_widget_inserted    | Flutter widget added to the tree           |
/// | T1_platform_view_created      | Native factory create() called             |
/// | T2_native_webview_created     | Native WebView object constructed          |
/// | T3_first_frame                | onPageStarted fired                        |
/// | T4_first_meaningful_progress  | Progress >= 10% (early render proxy)        |
/// | T5_page_finished              | onPageFinished fired                       |
///
/// > **T4 caveat**: "first meaningful progress" is a heuristic --- the real
/// > First Contentful Paint requires a JavaScript-based measurement injected
/// > by the benchmark tool. Do not label this as "First Paint" externally.
class StartupMilestone {
  final String name;

  /// Wall-clock epoch time in milliseconds (from [DateTime.now()] or
  /// [System.currentTimeMillis()] on Android).
  final int epochMs;

  const StartupMilestone({required this.name, required this.epochMs});

  Map<String, dynamic> toJson() => {'name': name, 'epochMs': epochMs};

  @override
  String toString() => '$name @ ${epochMs}ms';
}

// -- StartupTimelineEvent ------------------------------------------------------

/// Typed event emitted on [FixitWebViewController.diagnosticsStream] once
/// T5 is recorded.
///
/// Use [viewId] to correlate with the correct [FixitWebViewController] when
/// multiple WebViews are active simultaneously.
class StartupTimelineEvent {
  /// Identifies which WebView instance this timeline belongs to.
  final int viewId;

  /// Ordered list of milestones from T0 to T5.
  /// A milestone is absent if it was not reached (e.g. T5 before page loaded).
  final List<StartupMilestone> milestones;

  /// Raw human-readable timeline string produced by [FixitProfiler.buildTimeline()].
  final String rawTimeline;

  const StartupTimelineEvent({
    required this.viewId,
    required this.milestones,
    required this.rawTimeline,
  });

  /// Duration from T0 (Dart widget inserted) to T5 (page finished), or null
  /// if either milestone is missing.
  Duration? get totalStartupDuration {
    final t0 = _epochFor('T0_flutter_widget_inserted');
    final t5 = _epochFor('T5_page_finished');
    if (t0 == null || t5 == null) return null;
    return Duration(milliseconds: t5 - t0);
  }

  int? _epochFor(String name) {
    try {
      return milestones.firstWhere((m) => m.name == name).epochMs;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'viewId': viewId,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'rawTimeline': rawTimeline,
      };
}

// -- FixitDiagnosticsSnapshot --------------------------------------------------

/// A point-in-time snapshot of runtime state for diagnostic purposes.
/// Used by the benchmark tool, not for general SDK consumers.
class FixitDiagnosticsSnapshot {
  final int viewId;
  final String? currentUrl;
  final double progress;
  final bool isLoading;
  final int memoryUsage;
  final double fps;
  final List<String> errors;

  const FixitDiagnosticsSnapshot({
    required this.viewId,
    required this.currentUrl,
    required this.progress,
    required this.isLoading,
    required this.memoryUsage,
    required this.fps,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
        'viewId': viewId,
        'currentUrl': currentUrl ?? '',
        'progress': progress,
        'isLoading': isLoading,
        'memoryUsage': memoryUsage,
        'fps': fps,
        'errors': errors,
      };
}
