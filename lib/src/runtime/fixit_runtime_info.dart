/// Metadata describing a [FixitRuntime] instance, including its unique
/// identifier, SDK version, host platform, and creation timestamp.
class FixitRuntimeInfo {
  /// A unique identifier for this runtime instance.
  final String runtimeId;

  /// The version of the Fixit SDK used to create this runtime.
  final String sdkVersion;

  /// The operating system platform (e.g. 'android', 'ios', 'windows').
  final String platform;

  /// The date and time when this runtime was created.
  final DateTime createdAt;

  /// Creates a [FixitRuntimeInfo] with the given metadata.
  FixitRuntimeInfo({
    required this.runtimeId,
    required this.sdkVersion,
    required this.platform,
    required this.createdAt,
  });
}
