import 'bridge_handler.dart';

/// A registry that maps handler names to their corresponding [BridgeHandler] instances.
class BridgeRegistry {
  final Map<String, BridgeHandler> _handlers = {};

  /// Registers a [handler] under the given [name].
  void register(String name, BridgeHandler handler) {
    _handlers[name] = handler;
  }

  /// Retrieves the [BridgeHandler] registered for [name], or `null` if none.
  BridgeHandler? get(String name) => _handlers[name];
}
