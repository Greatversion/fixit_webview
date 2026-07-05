import 'dart:async';
import 'package:flutter/services.dart';

/// Represents a request from the web view to upload one or more files.
class UploadRequest {
  /// A unique identifier for this upload request.
  final int requestId;

  /// The list of accepted MIME types for file selection.
  final List<String> acceptTypes;

  /// Whether the device camera may be used for capture.
  final bool isCaptureEnabled;

  /// Whether multiple files may be selected.
  final bool allowsMultipleSelection;

  /// Creates an [UploadRequest] with the given properties.
  const UploadRequest({
    required this.requestId,
    this.acceptTypes = const [],
    this.isCaptureEnabled = false,
    this.allowsMultipleSelection = false,
  });
}

/// Reports the progress of an active upload operation.
class UploadProgress {
  /// The identifier of the upload request this progress relates to.
  final int requestId;

  /// The number of bytes sent so far.
  final int bytesSent;

  /// The total number of bytes to be sent.
  final int totalBytes;

  /// Creates an [UploadProgress] snapshot with the given values.
  const UploadProgress({
    required this.requestId,
    required this.bytesSent,
    required this.totalBytes,
  });

  /// The fraction of the upload completed, between 0.0 and 1.0.
  double get fraction => totalBytes > 0 ? bytesSent / totalBytes : 0.0;
}

/// Contains the result of a completed upload operation.
class UploadResult {
  /// The identifier of the upload request this result corresponds to.
  final int requestId;

  /// The list of file paths that were uploaded.
  final List<String> filePaths;

  /// Creates an [UploadResult] with the given [requestId] and [filePaths].
  const UploadResult({
    required this.requestId,
    required this.filePaths,
  });
}

/// Coordinates file upload operations between the web view and the native platform.
///
/// Emits streams for incoming upload requests and progress updates, manages
/// pending requests, and communicates with the native side via [MethodChannel].
class FixitUploadEngine {
  static const _channel = MethodChannel('com.fixit.fixit_webview/upload');

  final _requestController = StreamController<UploadRequest>.broadcast();
  final _progressController = StreamController<UploadProgress>.broadcast();
  final Map<int, Completer<List<String>>> _pendingRequests = {};

  /// A broadcast stream that emits when a new upload is requested by the web view.
  Stream<UploadRequest> get onUploadRequested => _requestController.stream;

  /// A broadcast stream that emits upload progress updates.
  Stream<UploadProgress> get onUploadProgress => _progressController.stream;

  /// Registers a pending upload [request] and emits it on [onUploadRequested].
  void registerRequest(UploadRequest request) {
    _pendingRequests[request.requestId] = Completer<List<String>>();
    _requestController.add(request);
  }

  /// Emits a progress update for the upload identified by [requestId].
  void handleProgress(int requestId, int bytesSent, int totalBytes) {
    _progressController.add(UploadProgress(
      requestId: requestId,
      bytesSent: bytesSent,
      totalBytes: totalBytes,
    ));
  }

  /// Awaits the selection of files for the upload identified by [requestId].
  ///
  /// Throws if no pending request exists for the given id.
  Future<List<String>> selectFiles(int requestId) async {
    final completer = _pendingRequests[requestId];
    if (completer == null) {
      throw Exception('No pending upload request with id $requestId');
    }
    return completer.future;
  }

  /// Resolves the pending upload for [requestId] with the selected [filePaths]
  /// and notifies the native platform via [MethodChannel].
  Future<void> resolveUpload(
      int viewId, int requestId, List<String> filePaths) async {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null) {
      completer.complete(filePaths);
    }
    try {
      await _channel.invokeMethod('resolveUpload', {
        'viewId': viewId,
        'requestId': requestId,
        'filePaths': filePaths,
      });
    } catch (e) {
      // If native side can't be reached, the request was already resolved via completer
    }
  }

  /// Cancels the upload for [requestId], completing the pending future with
  /// an error and notifying the native platform.
  Future<void> cancelUpload(int viewId, int requestId) async {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null) {
      completer.completeError(Exception('Upload cancelled'));
    }
    try {
      await _channel.invokeMethod('cancelUpload', {
        'viewId': viewId,
        'requestId': requestId,
      });
    } catch (_) {}
  }

  /// Releases all stream controllers and completes pending uploads as errors.
  void dispose() {
    _requestController.close();
    _progressController.close();
    for (final entry in _pendingRequests.entries) {
      entry.value.completeError(Exception('Upload engine disposed'));
    }
    _pendingRequests.clear();
  }
}
