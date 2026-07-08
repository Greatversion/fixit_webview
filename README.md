# Fixit WebView

[![pub package](https://img.shields.io/pub/v/fixit_webview)](https://pub.dev/packages/fixit_webview)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)](https://pub.dev/packages/fixit_webview)

A production-grade Flutter WebView plugin with a JavaScript bridge, native Dart module integration, offline engine, theme engine, and enterprise navigation controls. Designed for wrapping websites as native mobile apps with rich Dart ↔ Web interaction.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Core Concepts](#core-concepts)
  - [FixitWebView Widget](#fixitwebview-widget)
  - [FixitWebViewController](#fixitwebviewcontroller)
  - [FixitRuntime](#fixitruntime)
  - [FixitRuntimeConfig](#fixitruntimeconfig)
- [JavaScript Bridge](#javascript-bridge)
- [Navigation & Security](#navigation--security)
- [Upload Engine](#upload-engine)
- [Download Engine](#download-engine)
- [Offline Engine](#offline-engine)
- [Theme Engine](#theme-engine)
- [Permissions](#permissions)
- [Cookies & Sessions](#cookies--sessions)
- [Performance Diagnostics](#performance-diagnostics)
- [Force Update](#force-update)
- [Crash Recovery & Splash](#crash-recovery--splash)
- [Lifecycle Management](#lifecycle-management)
- [API Reference](#api-reference)
- [Platform Support](#platform-support)
- [Examples](#examples)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

- **WebView Runtime** — Full-featured WebView backed by Android System WebView and iOS WKWebView
- **JavaScript Bridge** — Bidirectional JS ↔ Dart communication via `window.FixitBridge` and CustomEvent protocol
- **Navigation Controls** — Whitelist/blacklist, deep links, URL routing, HTTP auth, SSL error handling
- **Offline Engine** — Cache-first and network-first strategies with disk persistence and retry queue
- **Upload Engine** — File upload from web forms with camera/gallery capture and multi-file support
- **Download Engine** — File download with progress tracking and system download manager integration
- **Theme Engine** — Auto light/dark CSS injection via `<style>` element, reactive to system brightness
- **Crash Recovery** — Automatic WebView restoration after renderer crash with custom overlay UI
- **Splash → WebView Transition** — Animated fade with configurable duration (white flash prevention)
- **Custom Loader** — Overlay with progress during page navigation
- **Force Update** — Remote version check with blocking or dismissible update dialog
- **Pull-to-Refresh** — Native `RefreshIndicator` integration
- **Permissions API** — Camera, microphone, and location permission check/request
- **OAuth Interceptor** — Automatic detection and parsing of OAuth callback URLs
- **Cookie & Session Management** — Persistent cookie store with disk backup
- **Memory Pressure Handling** — OS-level detection with auto cache clearing
- **Lifecycle Management** — Automatic pause/resume, cookie flushing, focus restoration
- **Pooling** — WebView instance pooling for faster cold starts
- **Performance Diagnostics** — Startup timeline (T0–T5), FPS, milestone export

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fixit_webview: ^0.10.0-beta.3
  fixit_core: ^1.0.1
```

Then run:

```bash
flutter pub get
```

> **Note:** `fixit_core` is a required peer dependency providing logging, caching, session, and event bus infrastructure.

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const WebViewExample());
  }
}

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

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
    ).then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixit WebView')),
      body: _ready
          ? FixitWebView(controller: _controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Flutter App                    │
├─────────────────────────────────────────────────┤
│  FixitWebView (Widget)                          │
│  FixitWebViewController (Controller)            │
├────────────────┬────────────────┬────────────────┤
│  FixitRuntime  │  JS Bridge     │  Navigation    │
│  (Lifecycle)   │  ↔ Web Page    │  Engine        │
├────────────────┴────────────────┴────────────────┤
│  Platform Interface (Pigeon / MethodChannel)     │
├────────────────┬────────────────┬────────────────┤
│  Android       │  iOS           │  ...           │
│  (WebView)     │  (WKWebView)   │                │
└────────────────┴────────────────┴────────────────┘
```

The SDK follows a **bridge + module** architecture:
- The **FixitRuntime** owns the WebView lifecycle and exposes platform APIs
- The **FixitWebViewController** provides the Dart-side API surface
- The **JavaScript Bridge** enables bidirectional communication between the web page and native Dart modules
- **Engines** (navigation, offline, upload, download, theme) are pluggable modules accessed through the controller

---

## Core Concepts

### FixitWebView Widget

The main widget that renders the native WebView. It handles:
- White flash prevention (splash → fade transition)
- Custom page-load loader overlay
- Crash recovery overlay
- Pull-to-refresh
- Lifecycle management (pause/resume)

```dart
FixitWebView(
  controller: _controller,
  config: FixitRuntimeConfig.builder()
    .enableWhiteFlashPrevention()
    .enableCrashRecovery()
    .enableCustomLoader()
    .build(),
  onRefresh: () => _controller.reload(),
)
```

### FixitWebViewController

The primary API surface for controlling the WebView. Provides:
- Navigation methods (`loadUrl`, `goBack`, `goForward`, `reload`, `stopLoading`)
- JavaScript execution (`evaluateJavascript`, `runJavascriptReturningResult`)
- State observables (`currentUrl`, `loading`, `progress`, `pageTitle`, `canGoBack`, `canGoForward`, `scrollOffset`)
- Bridge communication (`registerBridgeHandler`, `postBridgeMessage`, `invoke`)
- Cookie/session management (`setCookie`, `getCookies`, `clearCookies`)
- Upload/download control (`selectFiles`, `acceptDownload`, `cancelDownload`)
- Permission check/request (`checkPermission`, `requestPermission`)
- Navigation engine access (`navigationEngine`)
- Theme engine access (`themeEngine`)
- Offline engine access (`offlineEngine`)
- Crash/memory events (`onCrash`, `onRestart`, `memoryPressureLevel`)

### FixitRuntime

The central runtime that owns a WebView instance. Created via `FixitRuntime.create(viewId, context)`. Provides:
- Extension plugin registration
- Before/after load hooks
- Lifecycle initialization via `initialize(config)`

### FixitRuntimeConfig

Configuration object created via the builder pattern:

```dart
final config = FixitRuntimeConfig.builder()
  .setInitialUrl('https://example.com')
  .enableBridge()           // Enable JS ↔ Dart bridge
  .enablePooling()          // Enable WebView instance pooling
  .enableOffline()          // Enable offline caching
  .enableDownloads()        // Enable file downloads
  .setJavaScriptEnabled(true)
  .setDomStorageEnabled(true)
  .setCacheEnabled(true)
  .setAllowFileAccess(false)
  .setAcceptThirdPartyCookies(true)
  .setMaxUploadFileSize(100 * 1024 * 1024) // 100 MB
  .setAllowedUploadMimeTypes(['image/*', 'application/pdf'])
  .addNavigationWhitelist(['*.example.com'])
  .addNavigationBlacklist(['*.ads.com', '*.tracker.com'])
  .setExternalSchemes(['tel', 'mailto', 'sms'])
  .enableDiagnostics(level: DiagnosticsLevel.startup)
  .setUserAgent('MyApp/1.0')
  .setDownloadDirectory('/storage/downloads')
  .setAutoOpenDownload(true)
  .setThemeConfig(
    FixitThemeConfigBuilder()
      .setBackgroundColor(const Color(0xFFFAFAFA))
      .setTextColor(const Color(0xFF1A1A1A))
      .setAccentColor(const Color(0xFF6200EE))
      .setSurfaceColor(const Color(0xFFF5F5F5))
      .build(),
  )
  .enableWhiteFlashPrevention()
  .enableCustomLoader()
  .enableCrashRecovery()
  .enablePullToRefresh()
  .build();
```

---

## JavaScript Bridge

The bridge enables bidirectional communication between Dart and JavaScript running inside the WebView.

### How It Works

1. **Dart → JS**: Messages are dispatched as a `CustomEvent('fixit-bridge')` on `window` via `evaluateJavascript`
2. **JS → Dart**: JavaScript calls `window.FixitBridge.postMessage(JSON.stringify(...))` which is intercepted by a native `@JavascriptInterface` (Android) or `WKScriptMessageHandler` (iOS)
3. **RPC Invoke**: `controller.invoke(action, data)` sends a request, awaits a response from the page

### Registering a Dart Handler

```dart
controller.registerBridgeHandler('getUser', (message) async {
  // Called when JS sends a message to this handler
  return {'id': 42, 'name': 'Alice', 'email': 'alice@example.com'};
});
```

### Sending Messages from JavaScript

```javascript
// Send a message to a registered Dart handler
window.FixitBridge.postMessage(JSON.stringify({
  handlerName: 'getUser',
  action: 'fetch',
  data: { userId: 42 },
  callbackId: 'req_1'
}));
```

### RPC-Style Invoke from Dart

```dart
// Invoke an action on the page and wait for a response
final result = await controller.invoke('getUser', {'id': 42});
print(result); // {'id': 42, 'name': 'Alice'}
```

### Bridge Security

```dart
// Configure security constraints
final validator = BridgeValidator(
  config: BridgeSecurityConfig(
    allowedOrigins: ['https://example.com'],
    maxMessageSize: 1024 * 512, // 512 KB
    timeout: Duration(seconds: 30),
  ),
);

if (validator.isValidOrigin('https://example.com')) {
  // Process message
}
```

### BridgeMessage Structure

| Field | Type | Description |
|-------|------|-------------|
| `handlerName` | `String` | Name of the Dart handler to invoke |
| `action` | `String` | Action to perform |
| `data` | `Map<String, dynamic>` | Payload data |
| `callbackId` | `String` | Correlation ID for responses |

---

## Navigation & Security

### Navigation Engine

The `FixitNavigationEngine` provides URL interception, deep links, SSL error handling, and HTTP auth.

```dart
final engine = controller.navigationEngine;

// Listen to navigation requests
engine.onNavigationRequested.listen((request) {
  print('Navigating to: ${request.url}');
});

// Register URL routing rules
controller.registerNavigationRule(r'\.pdf$', 'external');
controller.registerNavigationRule(r'^https://api\.', 'block');

// Register external URL schemes
controller.registerExternalSchemes(['tel', 'mailto', 'facetime']);

// Handle deep links
controller.setDeepLinkHandler((url) {
  if (url.startsWith('myapp://')) {
    // Handle the deep link
    return true; // Consume the navigation
  }
  return false;
});
```

### SSL Errors

```dart
engine.onSslError.listen((error) async {
  print('SSL error on ${error.url}: ${error.error}');
  
  // Accept the error and proceed
  await controller.acceptSslError(error.url);
  
  // Or deny it
  // await controller.denySslError(error.url);
});
```

### HTTP Authentication

```dart
engine.onHttpAuthRequest.listen((request) async {
  // Provide credentials
  await controller.httpAuthResponse(
    requestId: request.requestId,
    username: 'user',
    password: 'pass',
  );
});
```

### Blocked Navigation

```dart
engine.onNavigationBlocked.listen((event) {
  print('Blocked ${event.url}: ${event.reason}');
});
```

### Navigation History

```dart
final history = engine.history;
print('Back stack: ${history.backStack.length} entries');
print('Forward stack: ${history.forwardStack.length} entries');
print('Current: ${history.current?.url}');
print('Can go back: ${history.canGoBack}');

// Navigate
await controller.goBack();
await controller.goForward();
```

### Security Config

```dart
await controller.updateSecurityConfig(
  mixedContentMode: 1,    // 0=never, 1=compat, 2=always
  safeBrowsingEnabled: true,
  zoomEnabled: true,
);
```

### OAuth Interceptor

Automatically detects OAuth callback URLs during navigation:

```dart
// Register a callback pattern
controller.registerOAuthCallbackPattern('callback');

// Check if a URL is an OAuth callback
final detected = controller.checkOAuthCallback(
  'https://myapp.com/callback?code=auth_code_xyz&state=abc123',
);

// Listen for detected OAuth callbacks
controller.oAuthInterceptor.onOAuthCallback.listen((callback) {
  print('OAuth code: ${callback.code}');
  print('Access token: ${callback.accessToken}');
  print('State: ${callback.state}');
});
```

---

## Upload Engine

Handles file upload requests triggered by `<input type="file">` elements in the web page.

```dart
// Listen for upload requests
controller.uploadEngine.onUploadRequested.listen((request) {
  print('Upload requested: #${request.requestId}');
  print('Accept types: ${request.acceptTypes}');
  print('Capture enabled: ${request.isCaptureEnabled}');
  print('Multiple: ${request.allowsMultipleSelection}');
  
  // Provide file paths in response
  await controller.selectFiles(request.requestId, ['/path/to/file.pdf']);
});

// Track upload progress
controller.uploadEngine.onUploadProgress.listen((progress) {
  print('Upload #${progress.requestId}: ${progress.bytesSent}/${progress.totalBytes} (${(progress.fraction * 100).toStringAsFixed(1)}%)');
});

// Cancel an upload
await controller.cancelUpload(requestId: 1);
```

**UploadRequest fields:**

| Field | Type | Description |
|-------|------|-------------|
| `requestId` | `int` | Unique request identifier |
| `acceptTypes` | `List<String>` | Accepted MIME types (e.g. `['image/*']`) |
| `isCaptureEnabled` | `bool` | Whether camera/gallery capture is available |
| `allowsMultipleSelection` | `bool` | Whether multiple files can be selected |

---

## Download Engine

Manages file downloads triggered by the web page or initiated programmatically.

```dart
// Listen for download requests
controller.downloadEngine.onDownloadRequested.listen((request) {
  print('Download: ${request.url}');
  print('MIME: ${request.mimeType}');
  print('Size: ${request.contentLength} bytes');
  
  // Accept and start the download
  await controller.acceptDownload(request.requestId);
});

// Track download progress
controller.downloadEngine.onDownloadProgress.listen((progress) {
  print('Download #${progress.requestId}: ${progress.receivedBytes}/${progress.totalBytes} (${(progress.fraction * 100).toStringAsFixed(1)}%)');
});

// Listen for completion
controller.downloadEngine.onDownloadCompleted.listen((result) {
  print('Saved to: ${result.filePath}');
});

// Listen for failures
controller.downloadEngine.onDownloadFailed.listen((failure) {
  final (requestId, error) = failure;
  print('Download #$requestId failed: $error');
});

// Cancel a download
await controller.cancelDownload(requestId: 1);

// Open a downloaded file with the system handler
await controller.openDownloadFile('/path/to/file.pdf', 'application/pdf');
```

**DownloadRequest fields:**

| Field | Type | Description |
|-------|------|-------------|
| `requestId` | `int` | Unique request identifier |
| `url` | `String` | Download URL |
| `mimeType` | `String` | MIME type of the file |
| `contentLength` | `int` | Expected file size (0 if unknown) |
| `contentDisposition` | `String` | Content-Disposition header value |

---

## Offline Engine

Provides caching, connectivity monitoring, and fallback for offline scenarios.

```dart
final offline = controller.offlineEngine;

// Check connectivity
offline.onConnectivityChanged.listen((state) {
  print(state == ConnectivityState.online ? 'Online' : 'Offline');
});

// Set cache strategy
offline.strategy = CacheStrategy.cacheFirst;
// Options: cacheFirst, networkFirst, networkOnly, cacheOnly

// Cache a response manually
await offline.cacheResponse(
  'https://example.com/page',
  '<html>...</html>',
  'text/html',
);

// Retrieve cached response
final cached = await offline.getCached('https://example.com/page');
if (cached != null) {
  print('Cached: ${cached.data} (${cached.mimeType})');
}

// Pre-cache multiple URLs
await offline.preCache([
  'https://example.com/style.css',
  'https://example.com/app.js',
]);

// Get all cached URLs
final urls = await offline.getCachedUrls();

// Clear cache
await offline.clearCache();

// Retry queue for failed requests
offline.enqueueRetry('https://example.com/failed-resource');
print('Pending retries: ${offline.pendingRetries}');

// Custom offline fallback HTML
offline.offlineFallbackHtml = '<html><body><h1>Offline</h1></body></html>';
```

**CacheStrategy options:**

| Strategy | Behavior |
|----------|----------|
| `cacheFirst` | Serve from cache if available; fetch from network otherwise |
| `networkFirst` | Fetch from network first; fall back to cache on failure |
| `networkOnly` | Always fetch from network |
| `cacheOnly` | Serve only from cache |

---

## Theme Engine

Injects CSS themes into the WebView page, reacting to system brightness changes.

```dart
final theme = controller.themeEngine;

// Inject a custom theme
await theme.injectTheme(
  ThemeDefinition(
    name: 'dark_mode',
    css: '''
      body { background: #121212 !important; color: #e0e0e0 !important; }
      a { color: #bb86fc !important; }
    ''',
  ),
);

// Reset theme
await theme.resetTheme();

// Auto-detect system brightness (default: true)
theme.autoDetect = true;

// Or use FixitThemeConfig for color-based generation
final config = FixitThemeConfigBuilder()
  .setBackgroundColor(const Color(0xFF121212))
  .setTextColor(const Color(0xFFE0E0E0))
  .setAccentColor(const Color(0xFFBB86FC))
  .setSurfaceColor(const Color(0xFF1E1E1E))
  .setPreferredBrightness(Brightness.dark)
  .build();

await theme.applyConfig(config);
```

---

## Permissions

Check and request runtime permissions for camera, microphone, and location.

```dart
// Check current permission state
final cameraStatus = await controller.checkPermission(PermissionType.camera);
final micStatus = await controller.checkPermission(PermissionType.microphone);
final locationStatus = await controller.checkPermission(PermissionType.location);

// Request permission (prompts user)
final result = await controller.requestPermission(PermissionType.camera);
if (result == PermissionStatus.granted) {
  // Camera access granted
}

// Track which features have been requested
controller.featureRegistry.isEnabled(NativeFeatureType.camera);
```

**PermissionStatus values:**

| Status | Description |
|--------|-------------|
| `granted` | Permission granted |
| `denied` | Permission denied (can be re-requested) |
| `deniedForever` | Permission denied permanently |
| `restricted` | Permission restricted by parental controls |
| `limited` | Granted with limited access (iOS) |

---

## Cookies & Sessions

### Cookie Manager

Persistent cookie storage with disk backup and platform-level synchronization.

```dart
// Set a cookie
await controller.setCookie('https://example.com', 'session_id', 'abc123');

// Get cookies
final cookies = await controller.getCookies('https://example.com');
// Returns: ['session_id=abc123', 'theme=dark']

// Get cookies as a map
final cookieMap = await controller.cookieManager.getCookiesAsMap('https://example.com');
print(cookieMap['session_id']); // 'abc123'

// Clear cookies for a specific URL
await controller.cookieManager.clearCookiesForUrl('https://example.com');

// Clear all cookies
await controller.clearCookies();
```

### Session Manager

Key-value session data with automatic persistence to disk (survives app restarts).

```dart
final session = controller.sessionManager;

// Store session data
await session.setValue('user_id', 42);
await session.setValue('auth_token', 'tok_abc');

// Retrieve session data
final userId = session.getValue('user_id'); // 42
final hasSession = session.hasSession; // true

// Session snapshot
final allData = session.snapshot();

// Remove a value
await session.removeValue('auth_token');

// Clear all session data
await controller.clearSession();
```

---

## Performance Diagnostics

Capture startup timeline and performance metrics.

```dart
// Enable diagnostics in config
final config = FixitRuntimeConfig.builder()
  .enableDiagnostics(level: DiagnosticsLevel.startup)
  .build();

// Listen for startup timeline events
controller.diagnosticsStream.listen((event) {
  for (final milestone in event.milestones) {
    print('${milestone.name}: ${milestone.epochMs}ms');
  }
});

// Or use the performance engine
final perf = FixitPerformanceEngine(runtimeInfo: runtime.info);
perf.recordLoadTime(Duration(milliseconds: 1500));
perf.recordMetrics(FixitPerformanceMetrics(
  fps: 60.0,
  memoryBytes: 52428800, // 50 MB
  cpuPercent: 15.0,
  loadTime: Duration(seconds: 2),
));
```

---

## Force Update

Check for app updates from a remote JSON endpoint and show a blocking or dismissible update screen.

```dart
// Check for updates
final result = await FixitForceUpdate.check(
  currentVersion: '1.0.0',
  minVersionUrl: 'https://example.com/version.json',
);

if (result.updateRequired) {
  // Show update screen
  if (result.forceUpdate) {
    await FixitForceUpdate.showForceUpdateScreen(
      context: context,
      result: result,
      barrierDismissible: false,
      onUpdate: () {
        // Open app store or download URL
      },
    );
  } else {
    // Dismissible update prompt
    await FixitForceUpdate.showForceUpdateScreen(
      context: context,
      result: result,
      barrierDismissible: true,
    );
  }
}
```

**Remote JSON format:**

```json
{
  "minVersion": "1.0.2",
  "force": true,
  "latestVersion": "1.2.0",
  "updateUrl": "https://play.google.com/store/apps/details?id=com.example.app"
}
```

---

## Crash Recovery & Splash

### Crash Recovery

The WebView automatically detects renderer crashes and can display a recovery overlay.

```dart
final config = FixitRuntimeConfig.builder()
  .enableCrashRecovery(
    crashOverlayBuilder: (context) => Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.reload(),
              child: const Text('Reload'),
            ),
          ],
        ),
      ),
    ),
  )
  .build();

// Listen for crash events
controller.onCrash.listen((event) {
  print('WebView crashed (viewId: ${event.viewId})');
});

// Listen for automatic restarts
controller.onRestart.listen((_) {
  print('WebView restored after crash');
});
```

### White Flash Prevention / Splash Transition

Prevents the white flash that occurs when a WebView loads by showing a splash screen that fades into the WebView.

```dart
final config = FixitRuntimeConfig.builder()
  .enableWhiteFlashPrevention(
    splashBuilder: (context) => Container(
      color: Colors.white,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    ),
  )
  .setSplashTransitionDuration(const Duration(milliseconds: 500))
  .build();
```

### Custom Page-Load Loader

Show a progress overlay during page navigation:

```dart
final config = FixitRuntimeConfig.builder()
  .enableCustomLoader(
    loaderBuilder: (context, progress) => Container(
      color: Colors.black26,
      child: Center(
        child: CircularProgressIndicator(value: progress),
      ),
    ),
  )
  .build();
```

---

## Lifecycle Management

The WebView automatically responds to app lifecycle changes (pause/resume).

```dart
// Manual lifecycle control
await controller.pause();   // Suspends JS timers, pauses media, flushes cookies
await controller.resume();  // Restarts JS timers, resumes media, restores focus
await controller.dispose(); // Releases all resources

// Memory pressure handling
controller.memoryPressureLevel.addListener(() {
  final level = controller.memoryPressureLevel.value;
  if (level == MemoryPressureLevel.critical) {
    // Cache was automatically cleared
    print('Critical memory pressure — caches cleared');
  }
});
```

---

## API Reference

### Widget

| Class | Description |
|-------|-------------|
| `FixitWebView` | The main WebView widget. Handles splash, crash, loader, pull-to-refresh. |

### Controller

| Class | Description |
|-------|-------------|
| `FixitWebViewController` | Primary controller for all WebView operations. |
| `ScrollUpdate` | Holds current scroll position and delta. |
| `WebViewCrashEvent` | Describes a WebView renderer crash event. |
| `MemoryPressureLevel` | OS memory pressure levels: `none`, `moderate`, `critical`. |

### Config

| Class | Description |
|-------|-------------|
| `FixitRuntimeConfig` | Configuration object with builder pattern. |
| `FixitRuntimeConfigBuilder` | Fluent builder for `FixitRuntimeConfig`. |
| `FixitCapabilities` | Tracks which capabilities are active. |
| `FixitCapability` | Enum: `pooling`, `bridge`, `downloads`, `offline`, `performance`, `experimental`, `enterprise`, `crashRecovery`, `memoryPressure`. |
| `FixitThemeConfig` | Holds color/brightness settings for CSS theme generation. |
| `FixitThemeConfigBuilder` | Fluent builder for `FixitThemeConfig`. |
| `FixitAIAdapter` | Abstract adapter for AI-powered page analysis. |
| `NativeFeatureRegistry` | Tracks which native device features have been used. |
| `NativeFeatureType` | Enum: `camera`, `gallery`, `location`, `microphone`. |

### Bridge

| Class | Description |
|-------|-------------|
| `FixitBridgeManager` | Manages registration and dispatching of bridge messages. |
| `BridgeHandler` | Abstract handler for JS → Dart bridge messages. |
| `BridgeMessage` | Represents a message from JS via the bridge. |
| `BridgeRegistry` | Maps handler names to `BridgeHandler` instances. |
| `BridgeValidator` | Validates bridge messages against security constraints. |
| `BridgeSecurityConfig` | Security config: allowed origins, max size, timeout. |

### Runtime

| Class | Description |
|-------|-------------|
| `FixitRuntime` | Central runtime owning a WebView instance. |
| `FixitRuntimeContext` | Shared services: logger, cache, cookies, session, events. |
| `FixitRuntimeInfo` | Metadata about a runtime instance. |
| `FixitExtensionPlugin` | Abstract extension point for `FixitRuntime`. |

### Navigation

| Class | Description |
|-------|-------------|
| `FixitNavigationEngine` | Navigation interception, SSL errors, HTTP auth, deep links. |
| `NavigationRequest` | Represents a WebView navigation attempt. |
| `SslErrorEvent` | SSL error encountered by the WebView. |
| `HttpAuthRequest` | HTTP authentication challenge. |
| `BlockedNavigation` | A navigation blocked by the rules engine. |
| `NavigationHistory` | Tracks back/forward navigation history. |
| `NavigationEntry` | A single entry in the navigation history. |
| `FixitUrlRulesEngine` | Regex-based URL routing rules. |
| `UrlRule` | A rule that matches URLs against a regex pattern. |
| `FixitOAuthInterceptor` | Detects OAuth callback URLs during navigation. |
| `OAuthCallback` | Parsed result of an OAuth callback URL. |
| `FixitRequest` | HTTP request that can be intercepted. |
| `FixitRequestInterceptor` | Abstract request interceptor. |
| `FixitResponse` | HTTP response that can be intercepted. |
| `FixitResponseInterceptor` | Abstract response interceptor. |
| `DeepLinkHandler` | Typedef: `bool Function(String url)`. |

### Upload

| Class | Description |
|-------|-------------|
| `FixitUploadEngine` | Coordinates file uploads between WebView and native. |
| `UploadRequest` | A file upload request from the web page. |
| `UploadProgress` | Progress of an active upload. |
| `UploadResult` | Result of a completed upload. |

### Download

| Class | Description |
|-------|-------------|
| `FixitDownloadEngine` | Coordinates file downloads between WebView and native. |
| `DownloadRequest` | A download request from the web page. |
| `DownloadProgress` | Progress of an active download. |
| `DownloadResult` | Result of a completed download. |

### Offline

| Class | Description |
|-------|-------------|
| `FixitOfflineEngine` | Offline caching, connectivity, retry queue. |
| `CachedResponse` | A previously cached HTTP response. |
| `ConnectivityState` | Enum: `online`, `offline`. |
| `CacheStrategy` | Enum: `cacheFirst`, `networkFirst`, `networkOnly`, `cacheOnly`. |

### Theme

| Class | Description |
|-------|-------------|
| `FixitThemeEngine` | Injects CSS themes into the WebView page. |
| `ThemeDefinition` | A named theme with CSS string. |

### Permissions

| Class | Description |
|-------|-------------|
| `FixitPermissionManager` | Singleton for runtime permission checks/requests. |
| `PermissionType` | Enum: `camera`, `microphone`, `location`. |
| `PermissionStatus` | Enum: `granted`, `denied`, `deniedForever`, `restricted`, `limited`. |

### Performance

| Class | Description |
|-------|-------------|
| `FixitPerformanceEngine` | Records FPS, memory, CPU, load time metrics. |
| `FixitPerformanceMetrics` | Snapshot of performance metrics. |

### Force Update

| Class | Description |
|-------|-------------|
| `FixitForceUpdate` | Remote version check with static methods. |
| `FixitForceUpdateScreen` | Update dialog widget (blocking or dismissible). |
| `ForceUpdateResult` | Result of a version check. |

### Cookies & Session

| Class | Description |
|-------|-------------|
| `FixitCookieManager` | Persistent cookie store with disk backup. |
| `FixitSessionManager` | Key-value session data with persistence. |
| `FixitCacheManager` | WebView cache lifecycle management. |

---

## Platform Support

| Platform | Minimum Version | Status |
|----------|----------------|--------|
| Android  | 8 (API 26)     | ✅ Production |
| iOS      | 15.0           | ✅ Production |

---

## Examples

The `example/` directory contains complete, runnable apps:

| Example | Location | Description |
|---------|----------|-------------|
| **Basic** | `example/lib/main.dart` | Minimal WebView with URL bar |
| **Advanced** | `example/lib/advanced/main.dart` | URL bar, JS console, navigation controls, progress tracking |
| **Benchmark** | `example/lib/benchmark/main.dart` | Startup timeline diagnostics with JSON export |

---

## Roadmap

- [x] JavaScript Bridge (Dart ↔ JS bidirectional communication)
- [x] Download Engine (file download with progress tracking)
- [x] Upload Engine (file upload from web forms)
- [x] Navigation & Security (whitelist/blacklist, SSL errors, HTTP auth)
- [x] Offline Engine (cache-first and network-first strategies)
- [x] Theme Engine (auto light/dark CSS injection)
- [x] Crash Recovery UI
- [x] Splash → WebView transition
- [x] Force Update
- [x] Performance Diagnostics
- [x] Cookie & Session Management


---

## License

MIT — see [LICENSE](LICENSE).
