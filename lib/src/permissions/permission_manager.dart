import 'package:flutter/services.dart';
import '../config/native_feature_registry.dart';

/// The type of native permission that can be requested or checked.
enum PermissionType {
  /// Access to the device camera.
  camera,

  /// Access to the device microphone.
  microphone,

  /// Access to the device location.
  location,
}

/// The status of a permission request.
enum PermissionStatus {
  /// The permission has been granted.
  granted,

  /// The permission has been denied.
  denied,

  /// The permission has been denied permanently.
  deniedForever,

  /// The permission is restricted.
  restricted,

  /// The permission is granted with limited access.
  limited,
}

/// Manages runtime permission checks and requests for native device features.
///
/// Uses a singleton pattern and communicates with the native platform via
/// [MethodChannel] to check and request camera, microphone, and location
/// permissions.
class FixitPermissionManager {
  static const _channel = MethodChannel('com.fixit.fixit_webview/permissions');

  static final FixitPermissionManager _instance = FixitPermissionManager._();

  /// Returns the singleton instance of [FixitPermissionManager].
  factory FixitPermissionManager() => _instance;
  FixitPermissionManager._();

  final NativeFeatureRegistry _featureRegistry = NativeFeatureRegistry();

  /// Returns the [NativeFeatureRegistry] used to track feature usage.
  NativeFeatureRegistry get featureRegistry => _featureRegistry;

  /// Checks the current [PermissionStatus] for the given [type] without prompting.
  Future<PermissionStatus> checkPermission(PermissionType type) async {
    _featureRegistry.register(_toFeatureType(type), true);
    final status = await _channel.invokeMethod<int>('checkPermission', {
      'type': type.index,
    });
    return PermissionStatus.values[status ?? PermissionStatus.denied.index];
  }

  /// Requests the [PermissionStatus] for the given [type], prompting the user if needed.
  Future<PermissionStatus> requestPermission(PermissionType type) async {
    _featureRegistry.register(_toFeatureType(type), true);
    final status = await _channel.invokeMethod<int>('requestPermission', {
      'type': type.index,
    });
    final granted = status == PermissionStatus.granted.index;
    _featureRegistry.register(_toFeatureType(type), granted);
    return PermissionStatus.values[status ?? PermissionStatus.denied.index];
  }

  static NativeFeatureType _toFeatureType(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return NativeFeatureType.camera;
      case PermissionType.microphone:
        return NativeFeatureType.microphone;
      case PermissionType.location:
        return NativeFeatureType.location;
    }
  }
}
