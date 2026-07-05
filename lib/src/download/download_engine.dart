import 'dart:async';
import 'package:flutter/services.dart';

/// Represents a file download request originating from the WebView.
class DownloadRequest {
  /// A unique identifier for this download request.
  final int requestId;

  /// The URL of the file to download.
  final String url;

  /// The MIME type of the file being downloaded.
  final String mimeType;

  /// The expected content length in bytes, or 0 if unknown.
  final int contentLength;

  /// The Content-Disposition header value from the server response.
  final String contentDisposition;

  /// Creates a [DownloadRequest] with the given properties.
  const DownloadRequest({
    required this.requestId,
    required this.url,
    this.mimeType = '',
    this.contentLength = 0,
    this.contentDisposition = '',
  });
}

/// Reports the progress of an active download operation.
class DownloadProgress {
  /// The identifier of the download request this progress relates to.
  final int requestId;

  /// The number of bytes received so far.
  final int receivedBytes;

  /// The total number of bytes expected.
  final int totalBytes;

  /// Creates a [DownloadProgress] snapshot with the given values.
  const DownloadProgress({
    required this.requestId,
    required this.receivedBytes,
    required this.totalBytes,
  });

  /// The fraction of the download completed, between 0.0 and 1.0.
  double get fraction => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
}

/// Contains the result of a completed download operation.
class DownloadResult {
  /// The identifier of the download request this result corresponds to.
  final int requestId;

  /// The local file path where the download was saved.
  final String filePath;

  /// Creates a [DownloadResult] with the given [requestId] and [filePath].
  const DownloadResult({
    required this.requestId,
    required this.filePath,
  });
}

/// Coordinates file download operations between the WebView and the native
/// platform, emitting streams for requests, progress, completion, and failure.
class FixitDownloadEngine {
  static const _channel = MethodChannel('com.fixit.fixit_webview/download');

  final _requestController = StreamController<DownloadRequest>.broadcast();
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _completedController = StreamController<DownloadResult>.broadcast();
  final _failedController = StreamController<(int, String)>.broadcast();
  final Map<int, Completer<String>> _pendingRequests = {};

  /// A broadcast stream that emits when a new download is requested.
  Stream<DownloadRequest> get onDownloadRequested => _requestController.stream;

  /// A broadcast stream that emits download progress updates.
  Stream<DownloadProgress> get onDownloadProgress => _progressController.stream;

  /// A broadcast stream that emits when a download completes successfully.
  Stream<DownloadResult> get onDownloadCompleted => _completedController.stream;

  /// A broadcast stream that emits when a download fails.
  Stream<(int, String)> get onDownloadFailed => _failedController.stream;

  /// Registers a pending download [request] and emits it on [onDownloadRequested].
  void registerRequest(DownloadRequest request) {
    _pendingRequests[request.requestId] = Completer<String>();
    _requestController.add(request);
  }

  /// Starts the download identified by [requestId] and returns the local file
  /// path once complete. Optionally specifies a [destinationDir].
  Future<String> startDownload(int requestId, {String? destinationDir}) async {
    final completer = _pendingRequests[requestId];
    if (completer == null) {
      throw Exception('No pending download request with id $requestId');
    }
    try {
      await _channel.invokeMethod('startDownload', {
        'requestId': requestId,
        'destinationDir': destinationDir ?? '',
      });
    } catch (e) {
      _pendingRequests.remove(requestId);
      rethrow;
    }
    return completer.future;
  }

  /// Accepts a download request from the WebView and starts downloading.
  Future<void> acceptDownload(int viewId, int requestId,
      {String? destinationDir}) async {
    try {
      await _channel.invokeMethod('startDownload', {
        'viewId': viewId,
        'requestId': requestId,
        'destinationDir': destinationDir ?? '',
      });
    } catch (_) {}
  }

  /// Cancels the download identified by [requestId].
  Future<void> cancelDownload(int requestId) async {
    _pendingRequests.remove(requestId);
    try {
      await _channel.invokeMethod('cancelDownload', {
        'requestId': requestId,
      });
    } catch (_) {}
  }

  /// Opens a downloaded file with the system default handler for [mimeType].
  Future<void> openFile(String filePath, String mimeType) async {
    try {
      await _channel.invokeMethod('openDownloadedFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }

  /// Emits a progress update for the download identified by [requestId].
  void handleProgress(int requestId, int receivedBytes, int totalBytes) {
    _progressController.add(DownloadProgress(
      requestId: requestId,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
    ));
  }

  /// Completes the download for [requestId] with the resulting [filePath].
  void handleCompleted(int requestId, String filePath) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null) {
      completer.complete(filePath);
    }
    _completedController.add(DownloadResult(
      requestId: requestId,
      filePath: filePath,
    ));
  }

  /// Marks the download for [requestId] as failed with [error].
  void handleFailed(int requestId, String error) {
    _pendingRequests.remove(requestId);
    _failedController.add((requestId, error));
  }

  /// Releases all stream controllers and completes pending requests as errors.
  void dispose() {
    _requestController.close();
    _progressController.close();
    _completedController.close();
    _failedController.close();
    for (final entry in _pendingRequests.entries) {
      entry.value.completeError(Exception('Download engine disposed'));
    }
    _pendingRequests.clear();
  }
}
