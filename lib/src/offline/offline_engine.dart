import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Describes the current network connectivity state of the device.
enum ConnectivityState {
  /// The device has network connectivity.
  online,

  /// The device does not have network connectivity.
  offline,
}

/// Defines the caching strategy used by [FixitOfflineEngine] when serving
/// WebView content.
enum CacheStrategy {
  /// Serve from cache if available, otherwise fetch from network.
  cacheFirst,

  /// Fetch from network first; fall back to cache on failure.
  networkFirst,

  /// Always fetch from network; never use the cache.
  networkOnly,

  /// Serve only from cache; never make network requests.
  cacheOnly,
}

/// Represents a previously cached HTTP response stored by the offline engine.
class CachedResponse {
  /// The URL that this cached response corresponds to.
  final String url;

  /// The body content of the cached response.
  final String data;

  /// The MIME type of the cached content (e.g. 'text/html').
  final String mimeType;

  /// The timestamp when this response was cached.
  final DateTime cachedAt;

  /// Creates a [CachedResponse] with the given properties.
  CachedResponse({
    required this.url,
    required this.data,
    required this.mimeType,
    required this.cachedAt,
  });

  /// Converts this cached response to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'url': url,
        'data': data,
        'mimeType': mimeType,
        'cachedAt': cachedAt.toIso8601String(),
      };

  /// Creates a [CachedResponse] from a JSON [Map].
  factory CachedResponse.fromJson(Map<String, dynamic> json) => CachedResponse(
        url: json['url'] as String,
        data: json['data'] as String,
        mimeType: json['mimeType'] as String,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
      );
}

/// Provides offline caching, connectivity monitoring, retry queuing, and
/// fallback HTML display for the WebView when the device is offline.
///
/// Supports multiple [CacheStrategy] options and synchronizes cached responses
/// with the native platform for seamless request interception.
class FixitOfflineEngine {
  static const _channel = MethodChannel('com.fixit.fixit_webview/offline');

  final _connectivityController =
      StreamController<ConnectivityState>.broadcast();
  CacheStrategy _strategy = CacheStrategy.networkFirst;
  int? _viewId;
  StreamSubscription<ConnectivityState>? _retrySub;
  String _fallbackHtml =
      '<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#121212;color:#e0e0e0"><div style="text-align:center"><h1>You are offline</h1><p>This content is not available offline.</p></div></body></html>';

  final List<String> _retryQueue = [];

  /// A broadcast stream that emits whenever the device connectivity changes.
  Stream<ConnectivityState> get onConnectivityChanged =>
      _connectivityController.stream;

  /// The current [CacheStrategy] used by the engine.
  CacheStrategy get strategy => _strategy;

  /// Sets the [CacheStrategy] and updates the automatic retry listener.
  set strategy(CacheStrategy value) {
    _strategy = value;
    _updateRetryListener();
  }

  /// The view ID associated with this engine, or `null` if not yet assigned.
  int? get viewId => _viewId;

  /// Assigns a view ID to enable native cache synchronization.
  set viewId(int? id) {
    _viewId = id;
  }

  /// The HTML content displayed when the device is offline and no cached
  /// version of the requested page is available.
  String get offlineFallbackHtml => _fallbackHtml;

  /// Sets a custom offline fallback HTML string.
  set offlineFallbackHtml(String html) {
    _fallbackHtml = html;
  }

  // ── Retry queue ──────────────────────────────────────────────────────────

  /// Enqueues [url] for automatic retry when connectivity is restored.
  void enqueueRetry(String url) {
    if (!_retryQueue.contains(url)) {
      _retryQueue.add(url);
    }
  }

  /// An unmodifiable list of URLs waiting to be retried.
  List<String> get pendingRetries => List.unmodifiable(_retryQueue);

  /// Clears all pending retry URLs.
  void clearRetryQueue() => _retryQueue.clear();

  void _updateRetryListener() {
    _retrySub?.cancel();
    _retrySub = null;
    if (_strategy == CacheStrategy.networkFirst) {
      _retrySub = _connectivityController.stream
          .where((s) => s == ConnectivityState.online)
          .listen((_) => _flushRetryQueue());
    }
  }

  Future<void> _flushRetryQueue() async {
    if (_retryQueue.isEmpty) return;
    final urls = List<String>.from(_retryQueue);
    _retryQueue.clear();
    final client = HttpClient();
    for (final url in urls) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final data = await response.transform(utf8.decoder).join();
        final ct = response.headers.contentType?.value ?? 'text/html';
        await cacheResponse(url, data, ct);
      } catch (_) {
        _retryQueue.add(url);
      }
    }
    client.close();
  }

  // ── File cache ───────────────────────────────────────────────────────────

  Future<Directory> _cacheDir() async {
    final appDir = await getApplicationCacheDirectory();
    final dir = Directory('${appDir.path}/fixit_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _metaPath() async {
    final dir = await _cacheDir();
    return '${dir.path}/cache_meta.json';
  }

  /// Caches the response [data] for [url] with the given [mimeType].
  /// Persists both the file data and metadata to disk, and syncs with the
  /// native platform cache.
  Future<void> cacheResponse(String url, String data, String mimeType) async {
    final dir = await _cacheDir();
    final key = _keyForUrl(url);
    final file = File('${dir.path}/$key');
    await file.writeAsString(data);

    final meta = await _loadMeta();
    meta[url] = {
      'key': key,
      'mimeType': mimeType,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    final metaFile = File(await _metaPath());
    await metaFile.writeAsString(jsonEncode(meta));

    // Sync to native cache map for shouldInterceptRequest
    await _setNativeCachedResponse(url, data, mimeType);
  }

  /// Returns the [CachedResponse] for [url], or `null` if not cached.
  Future<CachedResponse?> getCached(String url) async {
    final meta = await _loadMeta();
    final entry = meta[url];
    if (entry == null) return null;

    final dir = await _cacheDir();
    final file = File('${dir.path}/${entry['key']}');
    if (!await file.exists()) return null;

    final data = await file.readAsString();
    return CachedResponse(
      url: url,
      data: data,
      mimeType: entry['mimeType'] as String? ?? 'text/html',
      cachedAt: DateTime.parse(entry['cachedAt'] as String),
    );
  }

  /// Clears all cached responses from disk and the native cache store.
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _clearNativeCache();
  }

  /// Returns a list of all URLs that currently have a cached response.
  Future<List<String>> getCachedUrls() async {
    final meta = await _loadMeta();
    return meta.keys.toList();
  }

  String _keyForUrl(String url) {
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  Future<Map<String, Map<String, dynamic>>> _loadMeta() async {
    final metaFile = File(await _metaPath());
    if (!await metaFile.exists()) return {};
    try {
      final raw = await metaFile.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded
          .map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  // ── Native cache sync ────────────────────────────────────────────────────

  Future<void> _setNativeCachedResponse(
      String url, String data, String mimeType) async {
    final vId = _viewId;
    if (vId == null) return;
    try {
      await _channel.invokeMethod('setCachedResponse', {
        'viewId': vId,
        'url': url,
        'data': data,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }

  Future<void> _clearNativeCache() async {
    final vId = _viewId;
    if (vId == null) return;
    try {
      await _channel.invokeMethod('clearOfflineCache', {'viewId': vId});
    } catch (_) {}
  }

  /// Pushes the offline fallback HTML to the native platform so it can be
  /// displayed when the WebView requests an uncached URL while offline.
  Future<void> setNativeFallbackHtml(String html) async {
    final vId = _viewId;
    if (vId == null) return;
    try {
      await _channel.invokeMethod('setOfflineFallback', {
        'viewId': vId,
        'html': html,
      });
    } catch (_) {}
  }

  // ── Pre-cache ────────────────────────────────────────────────────────────

  /// Pre-caches the content of every URL in [urls] for offline use.
  /// Fetches each URL over the network and stores the response locally.
  Future<void> preCache(List<String> urls) async {
    final client = HttpClient();
    for (final url in urls) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final data = await response.transform(utf8.decoder).join();
        final ct = response.headers.contentType?.value ?? 'text/html';
        await cacheResponse(url, data, ct);
      } catch (_) {}
    }
    client.close();
    // Update native fallback with current fallback HTML
    await setNativeFallbackHtml(_fallbackHtml);
  }

  // ── Connectivity ─────────────────────────────────────────────────────────

  /// Notifies the engine of a [ConnectivityState] change, emitting it on
  /// [onConnectivityChanged].
  void handleConnectivityChange(ConnectivityState state) {
    _connectivityController.add(state);
  }

  /// Releases the connectivity stream and cancels the retry listener.
  void dispose() {
    _connectivityController.close();
    _retrySub?.cancel();
  }
}
