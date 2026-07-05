/// Identifies a named capability that can be toggled on or off in a [FixitRuntime].
enum FixitCapability {
  /// Enables HTTP connection pooling for reduced network latency.
  pooling,

  /// Enables the JavaScript-to-native bridge communication layer.
  bridge,

  /// Enables file download support from the WebView.
  downloads,

  /// Enables offline caching and connectivity-aware fallback behavior.
  offline,

  /// Enables performance metrics collection and monitoring.
  performance,

  /// Enables experimental features that may be unstable or change.
  experimental,

  /// Enables enterprise-grade security, compliance, and management features.
  enterprise,

  /// Enables automatic crash recovery with state restoration.
  crashRecovery,

  /// Enables monitoring and graceful handling of memory pressure events.
  memoryPressure,
}

/// Tracks which [FixitCapability] values are currently active in a runtime.
///
/// Use [isEnabled] for a general check or access the named getters for
/// convenient per-capability queries.
class FixitCapabilities {
  /// The set of capabilities that are currently marked as active.
  final Set<FixitCapability> activeCapabilities;

  /// Creates a [FixitCapabilities] with an optional [activeCapabilities] set.
  const FixitCapabilities({
    this.activeCapabilities = const {},
  });

  /// Returns `true` if [capability] is present in [activeCapabilities].
  bool isEnabled(FixitCapability capability) =>
      activeCapabilities.contains(capability);

  /// Whether connection pooling is enabled.
  bool get pooling => isEnabled(FixitCapability.pooling);

  /// Whether the JavaScript bridge is enabled.
  bool get bridge => isEnabled(FixitCapability.bridge);

  /// Whether file downloads are enabled.
  bool get downloads => isEnabled(FixitCapability.downloads);

  /// Whether offline caching and fallback is enabled.
  bool get offline => isEnabled(FixitCapability.offline);

  /// Whether performance monitoring is enabled.
  bool get performance => isEnabled(FixitCapability.performance);

  /// Whether experimental features are enabled.
  bool get experimental => isEnabled(FixitCapability.experimental);

  /// Whether enterprise features are enabled.
  bool get enterprise => isEnabled(FixitCapability.enterprise);

  /// Whether crash recovery is enabled.
  bool get crashRecovery => isEnabled(FixitCapability.crashRecovery);

  /// Whether memory pressure handling is enabled.
  bool get memoryPressure => isEnabled(FixitCapability.memoryPressure);
}
