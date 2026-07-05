/// Represents a message sent from JavaScript to the native side via the bridge.
class BridgeMessage {
  /// The name of the handler that should process this message.
  final String handlerName;

  /// The action to be performed by the handler.
  final String action;

  /// The payload data accompanying the message.
  final Map<String, dynamic> data;

  /// An identifier used to correlate responses with the originating call.
  final String callbackId;

  /// Creates a [BridgeMessage] with the given properties.
  BridgeMessage({
    required this.handlerName,
    required this.action,
    required this.data,
    required this.callbackId,
  });

  /// Creates a [BridgeMessage] from a JSON [Map].
  factory BridgeMessage.fromJson(Map<String, dynamic> json) {
    return BridgeMessage(
      handlerName: json['handlerName'] as String? ?? '',
      action: json['action'] as String? ?? '',
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
      callbackId: json['callbackId'] as String? ?? '',
    );
  }

  /// Converts this message to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'handlerName': handlerName,
        'action': action,
        'data': data,
        'callbackId': callbackId,
      };
}
