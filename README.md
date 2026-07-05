# Fixit WebView

A production-grade Flutter WebView SDK with a JavaScript bridge, native Dart module integration, offline engine, theme engine, and enterprise navigation controls.

## Features

- **WebView Runtime** — Full-featured WebView backed by Android System WebView and iOS WKWebView
- **JavaScript Bridge** — Bidirectional JS ↔ Dart communication via `FixitBridge`
- **Navigation Controls** — Whitelist/blacklist, deep links, URL routing, HTTP auth, SSL error handling
- **Offline Engine** — Cache-first and network-first strategies with custom fallback pages
- **Upload Engine** — File upload from web forms with capture intent support
- **Download Engine** — File download with progress tracking and system manager integration
- **Theme Engine** — Auto light/dark CSS injection with reactive switching
- **Performance Diagnostics** — Startup timeline (T0–T5), FPS, and milestone export
- **Crash Recovery** — Automatic WebView restoration after renderer crash
- **Pull-to-Refresh** — Native refresh gesture with programmatic support
- **White Flash Prevention** — Splash → WebView fade-in on first paint
- **Lifecycle Management** — Automatic pause/resume, cookie flushing, focus restoration
- **Memory Pressure Handling** — OS-level detection with auto cache clearing
- **Pooling** — WebView instance pooling for faster cold starts
- **Permissions API** — Camera, microphone, and location permission handling

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fixit_webview: ^0.9.0-beta.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:fixit_webview/fixit_webview.dart';
import 'package:fixit_core/fixit_core.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WebViewExample(),
    );
  }
}

class WebViewExample extends StatefulWidget {
  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _runtime = FixitRuntime.create(
      1,
      FixitRuntimeContext(
        logger: FixitLogger(label: 'example'),
        eventBus: FixitEventBus(),
        cache: FixitCacheManager(),
        cookies: FixitCookieManager(),
        session: FixitSessionManager(),
      ),
    );
    _controller = FixitWebViewController(_runtime);
    _runtime.initialize(
      FixitRuntimeConfig.builder()
        .setInitialUrl('https://flutter.dev')
        .enableBridge()
        .build(),
    ).then((_) {
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fixit WebView')),
      body: _ready
          ? FixitWebView(controller: _controller)
          : Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }
}
```

## Examples

### Basic Example

The `example/` directory contains a complete working app at `example/lib/main.dart`.

### Advanced Example

`example/lib/advanced/main.dart` demonstrates:
- URL bar with load/stop controls
- JavaScript execution console
- Navigation whitelist/blacklist
- Progress tracking
- Page title tracking

### Benchmark Example

`example/lib/benchmark/main.dart` demonstrates startup timeline diagnostics with export to JSON.

## JavaScript Bridge

Register Dart handlers for JavaScript calls:

```dart
controller.registerBridgeHandler('getUser', (message) async {
  return {'id': 42, 'name': 'Alice'};
});
```

From JavaScript, send messages:

```javascript
window.FixitBridge.postMessage(JSON.stringify({
  handlerName: 'getUser',
  callbackId: 'req_1'
}));
```

Use the RPC-style invoke from Dart:

```dart
final user = await controller.invoke('getUser', {'id': 42});
```

## Configuration

```dart
final config = FixitRuntimeConfig.builder()
  .setInitialUrl('https://example.com')
  .enableBridge()
  .enablePooling()
  .enableOffline()
  .enableDownloads()
  .setJavaScriptEnabled(true)
  .setDomStorageEnabled(true)
  .addNavigationWhitelist(['*.example.com'])
  .addNavigationBlacklist(['*.ads.com'])
  .setThemeConfig(FixitThemeConfigBuilder()
    .setLightColor(0xFFFAFAFA)
    .setDarkColor(0xFF121212)
    .build())
  .build();
```

## Platform Support

| Platform | Version | Status |
|----------|---------|--------|
| Android  | 8+      | ✅ Production |
| iOS      | 15+     | ✅ Production |

## API Overview

### Core
- `FixitWebView` — The main WebView widget
- `FixitWebViewController` — Controller for WebView operations
- `FixitRuntimeConfig` — Configuration with builder pattern
- `FixitRuntime` — Runtime lifecycle per WebView instance

### Bridge
- `FixitBridgeManager` — JS ↔ Dart message routing
- `BridgeHandler` — Abstract handler for bridge messages
- `BridgeValidator` — Security validation for bridge messages

### Navigation
- `FixitNavigationEngine` — URL rules, SSL errors, HTTP auth
- `FixitOAuthInterceptor` — OAuth callback detection
- `FixitUrlRulesEngine` — Regex-based routing rules

### Offline
- `FixitOfflineEngine` — Cache strategies and offline mode

### Theme
- `FixitThemeEngine` — CSS theme injection
- `FixitThemeConfig` — Color-based theme builder

### Upload & Download
- `FixitUploadEngine` — File upload management
- `FixitDownloadEngine` — File download management

### Permissions
- `FixitPermissionManager` — Runtime permission handling

### Performance
- `FixitPerformanceEngine` — FPS, memory, load time metrics

## Roadmap

- [ ] Push notifications with native FCM/APNs
- [ ] Splash screen → WebView transition
- [ ] Custom page-load loader
- [ ] WebView crash recovery UI
- [ ] Force update mechanism
- [ ] WebRTC permission callbacks

## License

MIT — see [LICENSE](LICENSE).
