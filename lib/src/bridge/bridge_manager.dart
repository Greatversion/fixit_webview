import 'package:fixit_core/fixit_core.dart';
import 'bridge_handler.dart';
import 'bridge_message.dart';
import 'bridge_registry.dart';

/// Manages registration and dispatching of bridge messages to registered handlers.
class FixitBridgeManager {
  /// The registry that stores all registered [BridgeHandler] instances.
  final BridgeRegistry registry = BridgeRegistry();
  final FixitLogger _logger = FixitLogger(label: 'BridgeManager');

  /// Registers a [handler] for the given [name].
  void register(String name, BridgeHandler handler) {
    registry.register(name, handler);
    _logger.debug('Registered JS Bridge Handler: $name');
  }

  /// Parses a JSON [Map] into a [BridgeMessage] and dispatches it to
  /// the appropriate registered handler, returning the result or an error map.
  Future<dynamic> handleMessage(Map<String, dynamic> jsonMap) async {
    try {
      final msg = BridgeMessage.fromJson(jsonMap);
      final handler = registry.get(msg.handlerName);
      if (handler == null) {
        _logger.warning('No handler found for: ${msg.handlerName}');
        return {'error': 'Handler not found'};
      }
      _logger.debug(
          'Invoking JS Bridge handler: ${msg.handlerName} with action: ${msg.action}');
      final result = await handler.handle(msg);
      return {'result': result};
    } catch (e, stack) {
      _logger.error('Failed to handle bridge message', err: e, stack: stack);
      return {'error': e.toString()};
    }
  }
}
