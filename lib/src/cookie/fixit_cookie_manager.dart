import 'dart:convert';
import 'dart:io';
import 'package:fixit_core/fixit_core.dart';
import 'package:path_provider/path_provider.dart';
import '../platform_interface/fixit_webview_platform.dart';

/// Manages HTTP cookies for WebView instances, providing persistence to disk
/// and synchronization with the platform-level cookie store.
class FixitCookieManager {
  final FixitLogger _logger = FixitLogger(label: 'CookieManager');
  final _localStore = <String, List<_CookieEntry>>{};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/fixit_cookies.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final cookies = (entry.value as List)
              .map((c) => _CookieEntry.fromJson(c as Map<String, dynamic>))
              .toList();
          _localStore[entry.key] = cookies;
        }
        _logger.debug('Loaded ${_localStore.length} cookie stores from disk');
      }
    } catch (e) {
      _logger.warning('Failed to load cookies from disk: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/fixit_cookies.json');
      final encoded = jsonEncode(_localStore.map(
        (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
      ));
      await file.writeAsString(encoded);
    } catch (e) {
      _logger.warning('Failed to persist cookies: $e');
    }
  }

  /// Sets a cookie for the given URL. Persists to disk and syncs with the
  /// platform WebView cookie store.
  Future<void> setCookie(String url, String key, String value) async {
    _logger.debug('Setting cookie for $url: $key=$value');
    await _ensureLoaded();
    final host = _hostFromUrl(url);
    _localStore.putIfAbsent(host, () => []);
    _localStore[host]!.removeWhere((c) => c.key == key);
    _localStore[host]!.add(_CookieEntry(key: key, value: value));
    await _persist();
    await FixitWebViewPlatform.instance.setCookie(url, key, value);
  }

  /// Retrieves all cookies for the given URL as a list of `key=value` strings.
  Future<List<String>> getCookies(String url) async {
    await _ensureLoaded();
    final host = _hostFromUrl(url);
    final stored = _localStore[host] ?? [];
    if (stored.isNotEmpty) {
      return stored.map((c) => '${c.key}=${c.value}').toList();
    }
    _logger.debug('Getting cookies for $url');
    return await FixitWebViewPlatform.instance.getCookies(url);
  }

  /// Retrieves all cookies for the given URL as a [Map] of cookie names to values.
  Future<Map<String, String>> getCookiesAsMap(String url) async {
    final raw = await getCookies(url);
    final map = <String, String>{};
    for (final entry in raw) {
      final parts = entry.split('=');
      if (parts.length >= 2) {
        map[parts[0]] = parts.sublist(1).join('=');
      }
    }
    return map;
  }

  /// Clears all cookies from both the local store and the platform WebView.
  Future<void> clearCookies() async {
    _localStore.clear();
    await _persist();
    await FixitWebViewPlatform.instance.clearCookies();
    _logger.debug('All cookies cleared');
  }

  /// Clears all cookies associated with the specified URL's host.
  Future<void> clearCookiesForUrl(String url) async {
    await _ensureLoaded();
    final host = _hostFromUrl(url);
    _localStore.remove(host);
    await _persist();
    _logger.debug('Cookies cleared for $host');
  }

  String _hostFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }
}

class _CookieEntry {
  final String key;
  final String value;

  _CookieEntry({required this.key, required this.value});

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  factory _CookieEntry.fromJson(Map<String, dynamic> json) =>
      _CookieEntry(key: json['key'] as String, value: json['value'] as String);
}
