import 'package:fixit_core/fixit_core.dart';
import '../platform_interface/fixit_webview_platform.dart';

/// Manages the WebView cache lifecycle, providing methods to clear cached
/// data for a given view.
class FixitCacheManager {
  final FixitLogger _logger = FixitLogger(label: 'CacheManager');

  /// Clears the cache for the WebView identified by [viewId].
  Future<void> clearCache(int viewId) async {
    _logger.debug('Clearing cache for view $viewId');
    await FixitWebViewPlatform.instance.clearCache(viewId);
  }
}
