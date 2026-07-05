/// The type of native device feature that can be registered and queried.
enum NativeFeatureType {
  /// The device camera.
  camera,

  /// The device photo gallery.
  gallery,

  /// The device location services.
  location,

  /// The device microphone.
  microphone,
}

/// Tracks which native device features have been enabled or used during the
/// current session.
class NativeFeatureRegistry {
  final Map<NativeFeatureType, bool> _registry = {};

  /// Registers [feature] with its current [isEnabled] state.
  void register(NativeFeatureType feature, bool isEnabled) {
    _registry[feature] = isEnabled;
  }

  /// Returns `true` if [feature] has been registered as enabled.
  bool isEnabled(NativeFeatureType feature) => _registry[feature] ?? false;
}
