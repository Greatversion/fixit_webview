// WebRTC Compatibility --- Not Yet Implemented
//
// Many client websites use WebRTC for Google Meet, Zoom,
// video consultation, and live classes.
//
// The browser's built-in WebRTC engine inside WKWebView / Android WebView
// already handles getUserMedia, RTCPeerConnection, and media streams.
// The runtime does NOT need a custom WebRTC stack.
//
// What the runtime DOES need:
//
//   1. Permission callbacks --- expose onCameraRequested / onMicrophoneRequested
//      streams on FixitWebViewController so the Flutter module can decide
//      whether to grant or deny.
//
//   2. Android WebChromeClient --- override onPermissionRequest to grant
//      camera/mic when getUserMedia is called by the page. Currently the
//      default WebChromeClient allows this, but we should route it through
//      the Dart permission callback for app-level control.
//
//   3. iOS WKUIDelegate --- wire the existing requestMediaCapturePermissionFor
//      stub (currently always .deny). Route the decision through the Dart
//      callback instead.
//
//   4. Ensure the WebView has camera/mic access --- the native WebView
//      already handles stream capture and encoding. No passthrough needed.
//
// Reference (Phase 5 --- Permissions) already builds the permission request
// infrastructure. WebRTC only needs the callback plumbing on top of that.
//
// -- Planned API surface -------------------------------------------------------
//
// Mixin or extension on FixitWebViewController:
//
//   Stream<WebRtcPermissionRequest> get onCameraRequested;
//   Stream<WebRtcPermissionRequest> get onMicrophoneRequested;
//
// class WebRtcPermissionRequest {
//   final String origin;
//   final bool isSecureContext;
//   void grant();
//   void deny();
// }
//
// -- Implementation order ------------------------------------------------------
//
// 1. Add onCameraRequested / onMicrophoneRequested streams to controller.
// 2. Android: override onPermissionRequest in WebChromeClient, send event
//    to Dart, await decision (grant / deny).
// 3. iOS: replace requestMediaCapturePermissionFor stub, send event to
//    Dart, await decision.
//
// This file intentionally left unimplemented --- build when WebRTC
// compatibility is required by client websites.
