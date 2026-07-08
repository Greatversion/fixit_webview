/// Represents an HTTP request that can be intercepted and modified before
/// it is sent by the WebView.
class FixitRequest {
  /// The URL being requested.
  final String url;

  /// The HTTP headers for the request.
  final Map<String, String> headers;

  /// Creates a [FixitRequest] with the given [url] and [headers].
  /// Creates a [FixitRequest] with the given [url] and [headers].
  FixitRequest({required this.url, required this.headers});
}

/// An interceptor that can inspect and modify [FixitRequest] objects before
/// they are dispatched by the WebView.
abstract class FixitRequestInterceptor {
  /// Called when a request is about to be made.
  /// Returns the (potentially modified) [request].
  Future<FixitRequest> onRequest(FixitRequest request);
}

/// Represents an HTTP response received by the WebView.
class FixitResponse {
  /// The HTTP status code of the response.
  final int statusCode;

  /// The MIME type of the response body, if known.
  final String? mimeType;

  /// The response body data.
  final dynamic data;

  /// Creates a [FixitResponse] with the given [statusCode], [mimeType], and [data].
  FixitResponse({required this.statusCode, this.mimeType, this.data});
}

/// An interceptor that can inspect and modify [FixitResponse] objects after
/// they are received by the WebView.
abstract class FixitResponseInterceptor {
  /// Called when a response is received.
  /// Returns the (potentially modified) [response].
  Future<FixitResponse> onResponse(FixitResponse response);
}
