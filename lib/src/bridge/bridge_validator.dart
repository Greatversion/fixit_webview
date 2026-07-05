/// Configuration for bridge security constraints such as allowed origins,
/// maximum message size, and timeout duration.
class BridgeSecurityConfig {
  /// The list of allowed origins for bridge messages. An empty list allows all.
  final List<String> allowedOrigins;

  /// The maximum allowed size (in bytes) for a bridge message.
  final int maxMessageSize;

  /// The timeout duration for bridge operations.
  final Duration timeout;

  /// Creates a [BridgeSecurityConfig] with the given constraints.
  const BridgeSecurityConfig({
    this.allowedOrigins = const [],
    this.maxMessageSize = 1024 * 512,
    this.timeout = const Duration(seconds: 30),
  });
}

/// Validates bridge messages against security constraints defined by
/// [BridgeSecurityConfig].
class BridgeValidator {
  /// The security configuration used for validation.
  final BridgeSecurityConfig config;

  /// Creates a [BridgeValidator] with an optional [config].
  const BridgeValidator({this.config = const BridgeSecurityConfig()});

  /// Returns `true` if [origin] is allowed by the security config.
  bool isValidOrigin(String origin) {
    if (config.allowedOrigins.isEmpty) return true;
    return config.allowedOrigins.any((allowed) => origin.contains(allowed));
  }

  /// Returns `true` if [message] does not exceed the maximum allowed size.
  bool isValidMessageSize(String message) {
    return message.length <= config.maxMessageSize;
  }

  /// Returns `true` if [message] contains valid `handlerName` and `action` keys.
  bool isValidMessage(Map<String, dynamic> message) {
    final handlerName = message['handlerName'] as String?;
    final action = message['action'] as String?;
    if (handlerName == null || handlerName.isEmpty) return false;
    if (action == null || action.isEmpty) return false;
    return true;
  }
}
