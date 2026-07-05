import 'dart:convert';
import 'dart:io';
import 'package:fixit_core/fixit_core.dart';
import 'package:path_provider/path_provider.dart';

/// Manages key-value session data with automatic persistence to disk.
/// Session data is restored on subsequent app launches.
class FixitSessionManager {
  final FixitLogger _logger = FixitLogger(label: 'SessionManager');
  final Map<String, dynamic> _sessionData = {};
  bool _loaded = false;
  static const _fileName = 'fixit_session.json';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _sessionData.addAll(decoded);
        _logger.debug('Session restored (${_sessionData.length} entries)');
      }
    } catch (e) {
      _logger.warning('Failed to load session: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(jsonEncode(_sessionData));
    } catch (e) {
      _logger.warning('Failed to persist session: $e');
    }
  }

  /// Stores a value in the session and persists it to disk.
  Future<void> setValue(String key, dynamic value) async {
    await _ensureLoaded();
    _sessionData[key] = value;
    await _persist();
  }

  /// Retrieves a session value by [key], or `null` if not found.
  dynamic getValue(String key) => _sessionData[key];

  /// Removes a session value by [key] and persists the change.
  Future<void> removeValue(String key) async {
    await _ensureLoaded();
    _sessionData.remove(key);
    await _persist();
  }

  /// Clears all session data and removes the persisted file.
  Future<void> clearSession() async {
    _sessionData.clear();
    await _persist();
    _logger.debug('Session cleared');
  }

  /// Whether the session currently contains any data.
  bool get hasSession => _sessionData.isNotEmpty;

  /// Returns an unmodifiable snapshot of all session data.
  Map<String, dynamic> snapshot() => Map.unmodifiable(_sessionData);
}
