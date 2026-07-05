import 'bridge_message.dart';

/// Defines a handler for processing messages from the JavaScript bridge.
///
/// Implementations receive a [BridgeMessage] and return a result asynchronously.
abstract class BridgeHandler {
  /// Processes the given [message] and returns the result of the operation.
  Future<dynamic> handle(BridgeMessage message);
}
