# Fixit WebView

[![pub package](https://img.shields.io/pub/v/fixit_webview)](https://pub.dev/packages/fixit_webview)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)](https://pub.dev/packages/fixit_webview)

A production-grade Flutter WebView plugin with a JavaScript bridge, native Dart module integration, offline engine, theme engine, and enterprise navigation controls. Designed for wrapping websites as native mobile apps with rich Dart ↔ Web interaction.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start (Complete App)](#quick-start-complete-app)
- [Architecture](#architecture)
- [Core Concepts](#core-concepts)
  - [FixitWebView Widget](#fixitwebview-widget)
  - [FixitWebViewController](#fixitwebviewcontroller)
  - [FixitRuntime](#fixitruntime)
  - [FixitRuntimeConfig](#fixitruntimeconfig)
  - [Lifecycle](#lifecycle)
- [JavaScript Bridge](#javascript-bridge)
  - [How It Works](#how-it-works)
  - [JS Side Setup](#js-side-setup)
  - [Dart Side Setup](#dart-side-setup)
  - [RPC-Style Communication](#rpc-style-communication)
  - [Security](#bridge-security)
  - [Real-World: Login Flow](#real-world-login-flow)
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
- [Putting It All Together](#putting-it-all-together)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Best Practices](#best-practices)
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
  fixit_webview: ^0.11.0-beta.1
  fixit_core: ^1.0.1
```

Then run:

```bash
flutter pub get
```

> **Note:** `fixit_core` is a required peer dependency providing logging, caching, session, and event bus infrastructure. You must add it to your `pubspec.yaml` even though `fixit_webview` depends on it transitively.

### Android Setup

No additional setup is required. The plugin uses Android System WebView (API 26+).

Add this permission to `android/app/src/main/AndroidManifest.xml` if you need network state detection:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS Setup

Target iOS 15.0+ in your `ios/Podfile`:

```ruby
platform :ios, '15.0'
```

---

## Quick Start (Complete App)

Here is a complete, copy-pasteable Flutter app that demonstrates:
- WebView initialization with runtime
- JS ↔ Dart bridge with a custom handler
- Navigation controls (back, forward, reload)
- URL loading from a text field
- Lifecycle management

### 1. Full App Code

**`main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fixit WebView',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  bool _ready = false;

  final TextEditingController _urlController =
      TextEditingController(text: 'https://flutter.dev');

  @override
  void initState() {
    super.initState();
    _initRuntime();
  }

  Future<void> _initRuntime() async {
    // 1. Create shared services context
    final context = FixitRuntimeContext(
      logger: FixitLogger(label: 'MyApp'),
      events: FixitEventBus(),
      cache: FixitCacheManager(),
      cookies: FixitCookieManager(),
      session: FixitSessionManager(),
    );

    // 2. Create runtime and controller
    _runtime = FixitRuntime.create(1, context);
    _controller = FixitWebViewController(_runtime);

    // 3. Register a bridge handler BEFORE initialize
    _controller.registerBridgeHandler('getUser', (message) async {
      // This is called when JS posts a message with handlerName: 'getUser'
      final userId = message.data['id'];
      return {
        'id': userId,
        'name': 'Alice',
        'email': 'alice@example.com',
      };
    });

    // 4. Build config and initialize
    final config = FixitRuntimeConfig.builder()
        .setInitialUrl(_urlController.text)
        .enableBridge()
        .setJavaScriptEnabled(true)
        .setDomStorageEnabled(true)
        .build();

    await _runtime.initialize(config);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _runtime.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixit WebView')),
      body: _ready ? _buildWebView() : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildWebView() {
    return Column(
      children: [
        // URL bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'Enter URL',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  onSubmitted: (url) => _controller.loadUrl(url),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _controller.loadUrl(_urlController.text),
                child: const Text('Go'),
              ),
            ],
          ),
        ),
        // Progress bar
        ValueListenableBuilder<double>(
          valueListenable: _controller.progress,
          builder: (_, progress, __) =>
              progress < 1.0 ? LinearProgressIndicator(value: progress) : const SizedBox.shrink(),
        ),
        // WebView
        Expanded(child: FixitWebView(controller: _controller)),
        // Navigation controls
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _controller.canGoBack,
                  builder: (_, can, __) => IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: can ? () => _controller.goBack() : null,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _controller.canGoForward,
                  builder: (_, can, __) => IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: can ? () => _controller.goForward() : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller.reload(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

### 2. Web Page with Bridge Integration

Create an `index.html` that your WebView loads. This demonstrates how the JS side communicates with Dart:

```html
<!DOCTYPE html>
<html>
<body>
  <h1>Fixit Bridge Demo</h1>
  <button onclick="getUser()">Get User Data</button>
  <button onclick="sendToDart()">Send Custom Event</button>
  <p id="output"></p>

  <script>
    // Send a message to Dart via the bridge
    function sendToDart() {
      window.FixitBridge.postMessage(JSON.stringify({
        handlerName: 'getUser',
        action: 'fetch',
        data: { id: 42 },
        callbackId: 'req_' + Date.now()
      }));
    }

    // Receive messages from Dart
    window.addEventListener('fixit-bridge', function(e) {
      // e.detail is a JSON string from Dart
      try {
        const msg = JSON.parse(e.detail);
        document.getElementById('output').textContent =
          'From Dart: ' + JSON.stringify(msg.data);
      } catch(err) {
        console.error('Bridge parse error:', err);
      }
    });

    // Also listen for RPC responses
    getVersion();
    function getVersion() {
      window.FixitBridge.postMessage(JSON.stringify({
        handlerName: 'getAppVersion',
        action: 'version',
        data: {},
        callbackId: 'req_version'
      }));
    }
  </script>
</body>
</html>
```

### 3. How It Works

1. **Runtime Initialization** — `FixitRuntime.create()` creates a named WebView instance with shared services
2. **Controller** — `FixitWebViewController` wraps the runtime and provides the full API surface
3. **Bridge Registration** — `registerBridgeHandler('getUser', ...)` registers a Dart handler that JS can call
4. **Configuration** — `FixitRuntimeConfig.builder()` builds the WebView settings
5. **Widget** — `FixitWebView(controller: _controller)` renders the native WebView
6. **JS Side** — The web page uses `window.FixitBridge.postMessage()` and listens for `fixit-bridge` events

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Flutter App                       │
│  ┌───────────────────────────────────────────────┐  │
│  │         FixitWebView (Widget)                 │  │
│  │  Splash, Loader, Crash UI, Pull-to-Refresh    │  │
│  └───────────────────┬───────────────────────────┘  │
│                      │                               │
│  ┌───────────────────▼───────────────────────────┐  │
│  │      FixitWebViewController (API Surface)      │  │
│  │  Navigation | Bridge | Upload | Download | ...  │  │
│  └───────┬──────────────┬──────────────┬────────┘  │
│          │              │              │            │
│  ┌───────▼──────┐ ┌────▼─────┐ ┌──────▼───────┐   │
│  │  FixitRuntime │ │ JS Bridge│ │   Engines    │   │
│  │  (Lifecycle)  │ │  ↔ Web   │ │ Nav,Upload,  │   │
│  │  (Pool)       │ │   Page   │ │ Download,... │   │
│  └───────┬───────┘ └─────────┘ └──────────────┘   │
│          │                                          │
│  ┌───────▼───────────────────────────────────────┐  │
│  │       Platform Interface (Pigeon + Channels)    │  │
│  └───────┬───────────────────────────────────────┘  │
│          │                                          │
├──────────┼──────────────────────────────────────────┤
│  ┌───────▼────────┐          ┌───────────────────┐  │
│  │   Android       │          │    iOS            │  │
│  │   (WebView)     │          │    (WKWebView)    │  │
│  └────────────────┘          └───────────────────┘  │
└─────────────────────────────────────────────────────┘
```

The SDK follows a **bridge + module** architecture:
- **FixitRuntime** owns the WebView lifecycle and exposes platform APIs
- **FixitWebViewController** provides the Dart-side API surface for all operations
- **JavaScript Bridge** enables bidirectional communication between the web page and native Dart modules
- **Engines** (navigation, offline, upload, download, theme) are pluggable modules accessed through the controller

---

## Core Concepts

### FixitWebView Widget

The main widget that renders the native WebView. It handles:
- White flash prevention (splash → fade transition via `AnimatedOpacity`)
- Custom page-load loader overlay
- Crash recovery overlay
- Pull-to-refresh
- Lifecycle management (pause/resume)

```dart
FixitWebView(
  controller: _controller,
  config: config,  // optional, can also set via controller
  onRefresh: () => _controller.reload(),
)
```

Config options that affect the widget appearance:

```dart
final config = FixitRuntimeConfig.builder()
    .enableWhiteFlashPrevention(
      splashBuilder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    )
    .setSplashTransitionDuration(const Duration(milliseconds: 500))
    .enableCustomLoader(
      loaderBuilder: (context, progress) => Container(
        color: Colors.black26,
        child: Center(
          child: CircularProgressIndicator(value: progress),
        ),
      ),
    )
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
                onPressed: () => _controller.reload(),
                child: const Text('Reload'),
              ),
            ],
          ),
        ),
      ),
    )
    .enablePullToRefresh()
    .build();
```

### FixitWebViewController

The primary API surface for controlling the WebView. All interactions go through this object.

**Navigation:**
| Method | Description |
|--------|-------------|
| `loadUrl(url)` | Navigate to a URL |
| `loadHtmlString(html)` | Load raw HTML |
| `goBack()` / `goForward()` | Navigate history |
| `reload()` | Reload current page |
| `stopLoading()` | Stop page load |
| `reload()` | Reload current page |

**Observables (ValueNotifier):**
| Observable | Type | Description |
|------------|------|-------------|
| `currentUrl` | `String?` | Current page URL |
| `loading` | `bool` | Whether page is loading |
| `progress` | `double` | Load progress (0.0–1.0) |
| `pageTitle` | `String?` | Page title from `<title>` |
| `canGoBack` | `bool` | Whether back navigation is available |
| `canGoForward` | `bool` | Whether forward navigation is available |

**Streams (for events you listen to):**
| Stream | Data Type | Description |
|--------|-----------|-------------|
| `diagnosticsStream` | `DiagnosticsEvent` | Startup timeline milestones |
| `onCrash` | `WebViewCrashEvent` | Renderer crash events |
| `onRestart` | `void` | Automatic WebView restorations |

**Methods for features:**
| Method | Description |
|--------|-------------|
| `registerBridgeHandler(name, handler)` | Register a JS bridge handler |
| `postBridgeMessage(message)` | Send a message from Dart to JS |
| `invoke(action, data)` | RPC-style Dart→JS call that awaits response |
| `evaluateJavascript(js)` | Execute JS (fire-and-forget) |
| `runJavascriptReturningResult(js)` | Execute JS and get a result |
| `setCookie(url, name, value)` | Set a browser cookie |
| `getCookies(url)` | Get cookies as strings |
| `clearCookies()` | Clear all cookies |
| `checkPermission(type)` | Check permission status |
| `requestPermission(type)` | Request a runtime permission |
| `pause()` / `resume()` | Manual lifecycle control |
| `dispose()` | Release all resources |

### FixitRuntime

The central runtime that owns a WebView instance. Created via:

```dart
final runtime = FixitRuntime.create(viewId: 1, context: runtimeContext);
```

**View ID** must be unique per WebView instance. Use `1` for a single WebView, increment for multiple instances.

**FixitRuntimeContext** provides shared services:
- `logger` — `FixitLogger` for debugging
- `events` — `FixitEventBus` for event propagation
- `cache` — `FixitCacheManager` for disk cache
- `cookies` — `FixitCookieManager` for persistent cookies
- `session` — `FixitSessionManager` for key-value session data

### FixitRuntimeConfig

Configuration object created via the builder pattern. Every option has a sensible default.

| Builder Method | Default | Description |
|---------------|---------|-------------|
| `setInitialUrl(url)` | — | First URL to load |
| `enableBridge()` | off | Enable JS ↔ Dart bridge |
| `enablePooling()` | off | Enable WebView instance pooling |
| `enableOffline()` | off | Enable offline caching |
| `enableDownloads()` | off | Enable file downloads |
| `setJavaScriptEnabled(bool)` | `true` | Enable JavaScript |
| `setDomStorageEnabled(bool)` | `true` | Enable DOM storage |
| `setCacheEnabled(bool)` | `true` | Enable WebView cache |
| `setAllowFileAccess(bool)` | `false` | Allow file:// URLs |
| `setAcceptThirdPartyCookies(bool)` | `false` | Accept 3rd party cookies |
| `setMediaPlaybackRequiresGesture(bool)` | `false` | Require user gesture for media |
| `setMaxUploadFileSize(int)` | no limit | Max upload file size |
| `setAllowedUploadMimeTypes(List)` | all | Allowed upload MIME types |
| `addNavigationWhitelist(List)` | none | Whitelisted URL patterns |
| `addNavigationBlacklist(List)` | none | Blacklisted URL patterns |
| `setExternalSchemes(List)` | none | External URL schemes |
| `enableDiagnostics(level)` | off | Performance diagnostics level |
| `setUserAgent(string)` | default | Custom user agent |
| `setDownloadDirectory(path)` | default | Download directory |
| `setAutoOpenDownload(bool)` | `false` | Auto-open downloaded files |
| `setThemeConfig(config)` | none | Theme engine configuration |
| `enableWhiteFlashPrevention()` | off | Show splash while loading |
| `setSplashTransitionDuration(Duration)` | 300ms | Splash → WebView fade duration |
| `enableCustomLoader()` | off | Show loader during navigation |
| `enableCrashRecovery()` | off | Show crash overlay |
| `enablePullToRefresh()` | off | Enable pull-to-refresh |

### Lifecycle

```
┌────────────┐
│  Created   │  FixitRuntime.create()
└─────┬──────┘
      │
┌─────▼──────┐
│ Initialized│  runtime.initialize(config)
|  (loading) │
└─────┬──────┘
      │
┌─────▼──────┐
│   Active   │  WebView is visible and interactive
│ (resumed)  │
└─────┬──────┘
      │
┌─────▼──────┐
│  Paused    │  App backgrounded: JS timers suspended,
│            │  cookies flushed to disk
└─────┬──────┘
      │
┌─────▼──────┐
│   Active   │  App foregrounded: JS timers resumed,
│ (resumed)  │  focus restored
└─────┬──────┘
      │
┌─────▼──────┐
│  Disposed  │  runtime.dispose(): all resources released
└────────────┘
```

Call `runtime.dispose()` in your widget's `dispose()` method when the WebView is no longer needed.

---

## JavaScript Bridge

The bridge is the core differentiator of Fixit WebView. It enables seamless bidirectional communication between Dart and JavaScript running inside the WebView.

### How It Works

```
Dart ──── evaluateJavascript ────► window.dispatchEvent(CustomEvent)
  │                                    │
  │                                    ▼
  │                              JS listens for 'fixit-bridge'
  │                                    │
  │                                    ▼
  │                              JS processes the message
  │                                    │
  │                                    ▼
  ◄────────── FixitBridge.postMessage ──┘
```

**Dart → JS:**
Dart sends messages by injecting JavaScript that dispatches a `CustomEvent('fixit-bridge', { detail: ... })` on `window`. Your page JS listens for this event.

**JS → Dart:**
JavaScript calls `window.FixitBridge.postMessage(jsonString)`. The native WebView layer intercepts this call and forwards the deserialized message to the registered Dart handler.

### JS Side Setup

Your web page needs two things to communicate with Dart:

1. **Listen for incoming messages** from Dart via `fixit-bridge` event
2. **Send outgoing messages** to Dart via `window.FixitBridge.postMessage()`

```javascript
// ====== bridge.js — Include this in your web page ======

(function() {
  'use strict';

  // --- Send messages to Dart ---
  window.FixitBridge = window.FixitBridge || {
    postMessage: function(jsonString) {
      // Native layer intercepts this call.
      // On Android: @JavascriptInterface annotated method
      // On iOS: WKUserContentController message handler
      // The jsonString must be a valid JSON string.
    }
  };

  // --- Receive messages from Dart ---
  window.addEventListener('fixit-bridge', function(event) {
    // event.detail is a JSON string from Dart
    const message = JSON.parse(event.detail);

    switch (message.action) {
      case 'navigate':
        window.location.href = message.data.url;
        break;
      case 'showToast':
        alert(message.data.text);
        break;
      case 'updateUser':
        updateUserUI(message.data);
        break;
      default:
        console.log('Unknown action:', message.action);
    }
  });

  // --- Helper: Send a structured message to Dart ---
  window.sendToDart = function(handlerName, action, data, callbackId) {
    window.FixitBridge.postMessage(JSON.stringify({
      handlerName: handlerName,
      action: action,
      data: data || {},
      callbackId: callbackId || ('cb_' + Date.now())
    }));
  };

  // --- Helper: Update UI with user data ---
  function updateUserUI(user) {
    var el = document.getElementById('user-info');
    if (el) {
      el.textContent = user.name + ' (' + user.email + ')';
    }
  }
})();
```

### Dart Side Setup

On the Dart side, register handlers for messages coming from JavaScript:

```dart
// Register a handler before calling runtime.initialize()
controller.registerBridgeHandler('getUser', (message) async {
  // message.data contains the JS payload
  final id = message.data['id'] as int?;

  // Fetch from your backend or local storage
  final user = await _fetchUserFromApi(id);

  // Return data to JS (it becomes the RPC response)
  return user;
});

// Register another handler
controller.registerBridgeHandler('getAppVersion', (message) async {
  return {
    'version': '1.0.0',
    'buildNumber': 42,
    'platform': Platform.isAndroid ? 'Android' : 'iOS'
  };
});

// Send a message TO the page (fire-and-forget)
await controller.postBridgeMessage(
  BridgeMessage(
    handlerName: 'system',
    action: 'showToast',
    data: {'text': 'Hello from Dart!'},
    callbackId: 'msg_1',
  ),
);

// RPC-style: invoke an action on JS and wait for response
final result = await controller.invoke('getUser', {'id': 42});
print(result); // {'id': 42, 'name': 'Alice', ...}
```

### BridgeMessage Structure

| Field | Type | Description |
|-------|------|-------------|
| `handlerName` | `String` | Name of the handler to invoke on the receiving side |
| `action` | `String` | Action to perform (e.g. 'fetch', 'update', 'delete') |
| `data` | `Map<String, dynamic>` | The payload data |
| `callbackId` | `String` | Correlation ID used to match responses to requests |

### Bridge Security

```dart
final validator = BridgeValidator(
  config: BridgeSecurityConfig(
    allowedOrigins: ['https://example.com', 'https://myapp.com'],
    maxMessageSize: 1024 * 512, // 512 KB max payload
    timeout: const Duration(seconds: 30),
  ),
);

if (validator.isValidOrigin('https://example.com')) {
  // Process the bridge message
}
if (validator.isValidMessageSize(jsonString.length)) {
  // Message is within size limit
}
```

### Real-World: Login Flow

A common use case is having the web page handle login and notify Dart of the result:

**Dart side:**
```dart
// Register login handler
controller.registerBridgeHandler('auth', (message) async {
  switch (message.action) {
    case 'loginSuccess':
      final token = message.data['accessToken'] as String;
      final user = message.data['user'] as Map<String, dynamic>;
      await _sessionManager.setValue('auth_token', token);
      await _sessionManager.setValue('user', user);
      return {'status': 'ok'};

    case 'logout':
      await _sessionManager.clearSession();
      return {'status': 'logged_out'};

    case 'checkSession':
      final token = _sessionManager.getValue('auth_token');
      return {'hasSession': token != null, 'token': token};
  }
  return {'error': 'unknown_action'};
});

// Send auth state to page after bridge is ready
await controller.postBridgeMessage(
  BridgeMessage(
    handlerName: 'auth',
    action: 'sessionRestored',
    data: {
      'token': _sessionManager.getValue('auth_token'),
      'user': _sessionManager.getValue('user'),
    },
    callbackId: 'session_sync',
  ),
);
```

**JS side:**
```javascript
// After successful login on the page
function onLoginSuccess(user, token) {
  window.sendToDart('auth', 'loginSuccess', {
    accessToken: token,
    user: user
  });
}

// On page load, check if already logged in
window.addEventListener('fixit-bridge', function(e) {
  const msg = JSON.parse(e.detail);
  if (msg.handlerName === 'auth' && msg.action === 'sessionRestored') {
    if (msg.data.token) {
      // Session restored — skip login screen
      restoreSession(msg.data.token, msg.data.user);
    }
  }
});
```

---

## Navigation & Security

### Navigation Engine

The `FixitNavigationEngine` provides URL interception, deep links, SSL error handling, and HTTP auth.

```dart
final engine = controller.navigationEngine;

// Listen to navigation requests
engine.onNavigationRequested.listen((request) {
  print('Navigating to: ${request.url}');
  print('Is main frame: ${request.isMainFrame}');
});

// Register URL routing rules
controller.registerNavigationRule(r'\.pdf$', 'external');
controller.registerNavigationRule(r'^https://api\.', 'block');

// Register external URL schemes
controller.registerExternalSchemes(['tel', 'mailto', 'sms', 'facetime']);

// Handle deep links
controller.setDeepLinkHandler((url) {
  if (url.startsWith('myapp://')) {
    // Parse and handle the deep link
    final route = url.replaceFirst('myapp://', '');
    print('Deep link received: $route');
    return true; // Consume the navigation (WebView won't load it)
  }
  return false; // Let WebView handle it normally
});
```

### SSL Errors

```dart
engine.onSslError.listen((error) async {
  print('SSL error on ${error.url}: ${error.error}');
  print('Error code: ${error.code}');

  // Accept the error and proceed
  await controller.acceptSslError(error.url);

  // Or deny it (page will not load)
  // await controller.denySslError(error.url);
});
```

### HTTP Authentication

```dart
engine.onHttpAuthRequest.listen((request) async {
  print('Auth required: ${request.host}:${request.port}');
  print('Realm: ${request.realm}');

  // Provide credentials
  await controller.httpAuthResponse(
    requestId: request.requestId,
    username: 'user',
    password: 'pass',
  );

  // Or cancel authentication:
  // await controller.cancelHttpAuthResponse(request.requestId);
});
```

### Blocked Navigation

```dart
engine.onNavigationBlocked.listen((event) {
  print('Blocked: ${event.url}');
  print('Reason: ${event.reason}');
  // Possible reasons: whitelist, blacklist, rule, deepLink
});
```

### Navigation History

```dart
final history = engine.history;
print('Back: ${history.backStack.length} entries');
print('Forward: ${history.forwardStack.length} entries');
print('Current URL: ${history.current?.url}');

// Navigate
await controller.goBack();
await controller.goForward();
```

### Security Config

```dart
await controller.updateSecurityConfig(
  mixedContentMode: 1,    // 0=never, 1=compat, 2=always
  safeBrowsingEnabled: true,  // Android only
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

print('Is OAuth callback: ${detected.isCallback}');
print('Code: ${detected.code}');
print('State: ${detected.state}');

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
  await controller.selectFiles(request.requestId, [
    '/storage/emulated/0/DCIM/photo.jpg',
  ]);
});

// Track upload progress
controller.uploadEngine.onUploadProgress.listen((progress) {
  print('${progress.bytesSent}/${progress.totalBytes} '
      '(${(progress.fraction * 100).toStringAsFixed(1)}%)');
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

  // Or reject:
  // await controller.cancelDownload(requestId: request.requestId);
});

// Track download progress
controller.downloadEngine.onDownloadProgress.listen((progress) {
  print('${progress.receivedBytes}/${progress.totalBytes} '
      '(${(progress.fraction * 100).toStringAsFixed(1)}%)');
});

// Listen for completion
controller.downloadEngine.onDownloadCompleted.listen((result) {
  print('Download #${result.requestId} saved to: ${result.filePath}');
});

// Listen for failures
controller.downloadEngine.onDownloadFailed.listen((failure) {
  final (requestId, error) = failure;
  print('Download #$requestId failed: $error');
});

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
  if (state == ConnectivityState.offline) {
    // Show offline indicator
  }
});

// Set cache strategy
offline.strategy = CacheStrategy.cacheFirst;
// Options: cacheFirst, networkFirst, networkOnly, cacheOnly

// Cache a response manually
await offline.cacheResponse(
  'https://example.com/page',
  '<html><body><h1>Cached</h1></body></html>',
  'text/html',
);

// Retrieve cached response
final cached = await offline.getCached('https://example.com/page');
if (cached != null) {
  print('Serving cached: ${cached.data}');
}

// Pre-cache critical resources
await offline.preCache([
  'https://example.com/style.css',
  'https://example.com/app.js',
  'https://example.com/logo.png',
]);

// Get all cached URLs
final urls = await offline.getCachedUrls();

// Clear cache
await offline.clearCache();

// Retry queue for failed requests
offline.enqueueRetry('https://example.com/failed-resource');
print('Pending retries: ${offline.pendingRetries}');

// Custom offline fallback HTML
offline.offlineFallbackHtml = '''
  <html>
  <body style="text-align:center;padding:40px;">
    <h1>You're Offline</h1>
    <p>Please check your connection.</p>
  </body>
  </html>
''';
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
      .header { background: #1e1e1e !important; }
    ''',
  ),
);

// Reset to no custom theme
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

// Request permission (prompts user if needed)
final result = await controller.requestPermission(PermissionType.camera);
if (result == PermissionStatus.granted) {
  print('Camera access granted');
} else if (result == PermissionStatus.deniedForever) {
  // Show a dialog directing user to Settings
  print('Camera permission denied permanently');
}

// Track which features have been used
controller.featureRegistry.isEnabled(NativeFeatureType.camera);
```

**PermissionStatus values:**

| Status | Description |
|--------|-------------|
| `granted` | Permission granted |
| `denied` | Permission denied (can be re-requested) |
| `deniedForever` | Permission denied permanently (go to Settings) |
| `restricted` | Permission restricted by parental controls |
| `limited` | Granted with limited access (iOS photo library) |

---

## Cookies & Sessions

### Cookie Manager

Persistent cookie storage with disk backup and platform-level synchronization.

```dart
// Set a cookie (domain-scoped)
await controller.setCookie('https://example.com', 'session_id', 'abc123');
await controller.setCookie('https://example.com', 'theme', 'dark');

// Get cookies for a URL
final cookies = await controller.getCookies('https://example.com');
// Returns: ['session_id=abc123', 'theme=dark']

// Get cookies as a map
final cookieMap =
    await controller.cookieManager.getCookiesAsMap('https://example.com');
print(cookieMap['session_id']); // 'abc123'
print(cookieMap['theme']);      // 'dark'

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
await session.setValue('auth_token', 'tok_abc123');
await session.setValue('onboarding_complete', true);

// Retrieve session data
final userId = session.getValue('user_id'); // 42
final hasToken = session.has('auth_token'); // true
final hasSession = session.hasSession;      // true

// Get all data as a map
final allData = session.snapshot();
print(allData); // {'user_id': 42, 'auth_token': 'tok_abc123', ...}

// Remove a specific key
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

// Or use the performance engine directly
final perf = FixitPerformanceEngine(runtimeInfo: runtime.info);
perf.recordLoadTime(const Duration(milliseconds: 1500));
perf.recordMetrics(FixitPerformanceMetrics(
  fps: 60.0,
  memoryBytes: 52428800, // 50 MB
  cpuPercent: 15.0,
  loadTime: Duration(seconds: 2),
));

// Export performance report
final report = perf.exportReport();
print(report);
```

**Diagnostics milestones (T0–T5):**
| Milestone | Description |
|-----------|-------------|
| `T0` | Runtime created |
| `T1` | Config initialized |
| `T2` | Native WebView created |
| `T3` | URL loading started |
| `T4` | Page started loading |
| `T5` | Page finished loading |

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
  // Show blocking update screen (user MUST update)
  if (result.forceUpdate) {
    await FixitForceUpdate.showForceUpdateScreen(
      context: context,
      result: result,
      barrierDismissible: false, // Blocking — user cannot dismiss
      onUpdate: () {
        // Open Play Store / App Store
        launchUrl(Uri.parse(result.updateUrl ?? ''));
      },
    );
  } else {
    // Show dismissible update prompt
    await FixitForceUpdate.showForceUpdateScreen(
      context: context,
      result: result,
      barrierDismissible: true, // User can dismiss
    );
  }
} else {
  print('App is up to date');
}
```

**Remote JSON endpoint** should return:

```json
{
  "minVersion": "1.0.2",
  "force": true,
  "latestVersion": "1.2.0",
  "updateUrl": "https://play.google.com/store/apps/details?id=com.example.app"
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `minVersion` | `String` | Minimum required version (semver) |
| `force` | `Boolean` | Whether update is mandatory |
| `latestVersion` | `String` | Latest available version |
| `updateUrl` | `String` | URL to download the update |

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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => controller.reload(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
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
  // You could send a crash report to your analytics
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
        child: SizedBox(
          width: 120,
          child: LinearProgressIndicator(value: progress),
        ),
      ),
    ),
  )
  .build();
```

---

## Putting It All Together

A complete Flutter app that uses multiple features together: bridge, navigation, offline, theme, and force update.

```dart
import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fixit Production App',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Shared services
    final context = FixitRuntimeContext(
      logger: FixitLogger(label: 'ProductionApp'),
      events: FixitEventBus(),
      cache: FixitCacheManager(),
      cookies: FixitCookieManager(),
      session: FixitSessionManager(),
    );

    // 2. Runtime & controller
    _runtime = FixitRuntime.create(1, context);
    _controller = FixitWebViewController(_runtime);

    // 3. Check for force update
    final forceResult = await FixitForceUpdate.check(
      currentVersion: '1.0.0',
      minVersionUrl: 'https://example.com/version.json',
    );

    if (forceResult.updateRequired && mounted) {
      await FixitForceUpdate.showForceUpdateScreen(
        context: context,
        result: forceResult,
        barrierDismissible: !forceResult.forceUpdate,
        onUpdate: () {
          // Open app store
        },
      );
    }

    // 4. Register bridge handlers
    _controller.registerBridgeHandler('getUser', (message) async {
      return {'id': 42, 'name': 'Alice'};
    });
    _controller.registerBridgeHandler('auth', (message) async {
      if (message.action == 'loginSuccess') {
        await _runtime.context.session
            .setValue('auth_token', message.data['token']);
        return {'status': 'ok'};
      }
      return {'error': 'unknown'};
    });

    // 5. Configure and initialize
    final config = FixitRuntimeConfig.builder()
        .setInitialUrl('https://example.com')
        .enableBridge()
        .enableOffline()
        .enableDownloads()
        .enableWhiteFlashPrevention()
        .enableCrashRecovery()
        .enablePullToRefresh()
        .setJavaScriptEnabled(true)
        .setDomStorageEnabled(true)
        .setCacheEnabled(true)
        .addNavigationWhitelist(['*.example.com'])
        .build();

    await _runtime.initialize(config);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: _ready
          ? FixitWebView(
              controller: _controller,
              onRefresh: () => _controller.reload(),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
```

---

## Troubleshooting & FAQ

### Bridge doesn't work

**Problem:** `window.FixitBridge` is undefined in the web page.

**Solution 1:** Make sure `enableBridge()` is called in the config:
```dart
final config = FixitRuntimeConfig.builder()
  .enableBridge()  // ← Required!
  .build();
```

**Solution 2:** Check that the page is fully loaded before calling bridge methods. Use the `loading` notifier:
```dart
_valueListenableBuilder<bool>(
  valueListenable: _controller.loading,
  builder: (_, isLoading, __) {
    if (!isLoading) {
      // Page loaded — safe to use bridge
    }
    return ...;
  },
);
```

### WebView shows white screen

**Problem:** The WebView displays a white screen instead of the page.

**Solution 1:** Enable white flash prevention with a splash:
```dart
.enableWhiteFlashPrevention(
  splashBuilder: (context) => Container(
    color: Colors.white,
    child: const Center(child: CircularProgressIndicator()),
  ),
)
```

**Solution 2:** Check that the URL is accessible and HTTPS. Some sites block WebView user agents.

### Navigation rules not blocking ads

**Problem:** Blacklisted URLs still load.

**Solution:** Use glob-style patterns with wildcards:
```dart
.addNavigationBlacklist(['*://*.doubleclick.net/*', '*://*.googlesyndication.com/*'])
.addNavigationBlacklist(['*://*.ads.*'])
```

### Downloads not working

**Problem:** Download requests are not intercepted.

**Solution 1:** Make sure `enableDownloads()` is in the config.

**Solution 2:** Verify the MIME type is in the allowed list. Add explicit types:
```dart
.setAllowedUploadMimeTypes(['image/*', 'application/pdf', 'video/*'])
```

### Offline engine not caching

**Problem:** Resources are not served from cache when offline.

**Solution 1:** Ensure `enableOffline()` is in the config.

**Solution 2:** Set the strategy to `cacheFirst` or `networkFirst`:
```dart
offline.strategy = CacheStrategy.cacheFirst;
```

**Solution 3:** Pre-cache critical resources explicitly:
```dart
await offline.preCache(['https://example.com/', 'https://example.com/app.js']);
```

### MissingPluginException

**Problem:** `MissingPluginException` at runtime.

**Solution:** This usually means the plugin wasn't registered. Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

### SecurityException crash on Android

**Problem:** Crash with `SecurityException` on some Android devices.

**Solution:** Add the network state permission to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

## Best Practices

1. **Register bridge handlers before `runtime.initialize()`** — Handlers are wired up during initialization. Registering after may miss early messages.

2. **Dispose the runtime in your widget's `dispose()`** — Always call `_runtime.dispose()` to prevent memory leaks:
   ```dart
   @override
   void dispose() {
     _runtime.dispose();
     super.dispose();
   }
   ```

3. **Use `mounted` check before `setState`** — After async operations, check if the widget is still mounted:
   ```dart
   await _runtime.initialize(config);
   if (mounted) setState(() => _ready = true);
   ```

4. **Set initial URL on the first build** — Pass the initial URL via config, not by calling `loadUrl()` in `initState`.

5. **Use `ValueListenableBuilder` for reactive UI** — Instead of polling, use the built-in `ValueListenable` properties like `_controller.progress`, `_controller.loading`, `_controller.canGoBack`.

6. **Configure navigation rules early** — Set whitelist/blacklist and external schemes during config setup, not after the page loads.

7. **Pre-cache for offline-first apps** — If your app needs to work offline, call `offline.preCache()` during initialization.

8. **Handle OAuth callbacks** — Register callback patterns before navigation starts to capture redirects:
   ```dart
   controller.registerOAuthCallbackPattern('callback');
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

## License

MIT — see [LICENSE](LICENSE).
