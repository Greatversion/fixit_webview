# Changelog

## 0.9.0-beta.1

Initial beta release of the Fixit WebView SDK.

### Features

- **WebView Runtime** — Full-featured WebView with platform-specific native backends (Android WebView + iOS WKWebView)
- **JS Bridge** — Bidirectional JavaScript ↔ Dart communication via `FixitBridge`
- **Navigation Engine** — Whitelist/blacklist rules, deep link handling, URL routing, HTTP auth, SSL error handling
- **Offline Engine** — Cache-first and network-first strategies, connectivity monitoring, custom offline fallback pages
- **Upload Engine** — File upload handling from web forms with multi-file support and capture intent
- **Download Engine** — File download management with progress tracking and system download manager integration
- **Theme Engine** — Auto light/dark CSS theme injection with `ValueNotifier`-based reactive switching
- **Lifecycle Management** — Automatic pause/resume, JS timer suspension, cookie flushing, focus restoration
- **Renderer Crash Recovery** — Automatic WebView restoration after Android `onRenderProcessGone` / iOS process termination
- **Pull-to-Refresh** — Native refresh gesture with programmatic refresh support
- **White Flash Prevention** — Splash → invisible WebView → fade-in on first paint
- **Memory Pressure Handling** — OS-level memory pressure detection with automatic cache clearing
- **First Paint Detection** — `controller.onFirstPaint` ValueNotifier for splash removal, analytics, and benchmarking
- **Performance Diagnostics** — Startup timeline tracing (T0–T5), FPS, and milestone export
- **Pooling** — WebView instance pooling for faster cold starts
- **Permissions API** — Runtime camera, microphone, and location permission handling
- **Cookie & Session Management** — Persistent cookie store and session data with JSON serialization
- **OAuth Interceptor** — Automatic OAuth callback URL detection and interception
- **Security Config** — Runtime mixed content mode, safe browsing, and zoom control

### Breaking Changes

This is a new package — no breaking changes from any prior release.

### Known Limitations

- iOS WKWebView has no public API to disable safe browsing
- iOS WKWebView has no public mixed-content API
- `pigeon` usage requires re-generation when adding new platform channel methods
- Custom fonts in WebView require manual CSS injection via the Theme Engine
