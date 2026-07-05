import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';

/// Advanced example demonstrating Phase 1 features:
/// - Navigation whitelist/blacklist
/// - loadHtmlString
/// - evaluateJavascript / runJavascriptReturningResult
/// - stopLoading
/// - clearCache / clearCookies
/// - Page title tracking
/// - Console message logging
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AdvancedExampleApp(),
  ));
}

class AdvancedExampleApp extends StatefulWidget {
  const AdvancedExampleApp({super.key});

  @override
  State<AdvancedExampleApp> createState() => _AdvancedExampleAppState();
}

class _AdvancedExampleAppState extends State<AdvancedExampleApp> {
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  late final FixitRuntimeConfig _config;
  bool _isReady = false;

  final TextEditingController _urlInput = TextEditingController(text: 'https://flutter.dev');
  final TextEditingController _jsInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final ctx = FixitRuntimeContext(
      logger: FixitLogger(label: 'AdvancedExample'),
      events: FixitEventBus(),
      cache: FixitCacheManager(),
      cookies: FixitCookieManager(),
      session: FixitSessionManager(),
    );

    _runtime = FixitRuntime.create(1, ctx);
    _controller = FixitWebViewController(_runtime);

    _config = FixitRuntimeConfig.builder()
        .setInitialUrl(_urlInput.text)
        .setJavaScriptEnabled(true)
        .setDomStorageEnabled(true)
        .setCacheEnabled(true)
        .setMediaPlaybackRequiresGesture(false)
        .build();

    await _runtime.initialize(_config);
    if (mounted) setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _runtime.dispose();
    _urlInput.dispose();
    _jsInput.dispose();
    super.dispose();
  }

  void _runJs() async {
    final js = _jsInput.text;
    if (js.isEmpty) return;

    final result = await _controller.runJavascriptReturningResult(js);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JS Result: $result')),
      );
    }
  }

  void _loadHtml() {
    _controller.loadHtmlString(
      '<html><body style="font-family:sans-serif;padding:20px;">'
      '<h1>Hello from loadHtmlString!</h1>'
      '<p>This was loaded as a raw HTML string.</p>'
      '</body></html>',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String?>(
          valueListenable: _controller.pageTitle,
          builder: (_, title, __) => Text(title ?? 'Advanced Example'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear Cache', onPressed: () => _controller.clearCache()),
          IconButton(icon: const Icon(Icons.cookie_outlined), tooltip: 'Clear Cookies', onPressed: () => _controller.clearCookies()),
          IconButton(icon: const Icon(Icons.code), tooltip: 'Load HTML String', onPressed: _loadHtml),
        ],
      ),
      body: Column(
        children: [
          // URL bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlInput,
                    decoration: const InputDecoration(
                      hintText: 'URL', border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (url) => _controller.loadUrl(url),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => _controller.loadUrl(_urlInput.text), child: const Text('Go')),
              ],
            ),
          ),

          // JS console
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _jsInput,
                    decoration: const InputDecoration(
                      hintText: 'document.title', border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _runJs(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _runJs, child: const Text('Run JS')),
              ],
            ),
          ),

          // Progress
          ValueListenableBuilder<double>(
            valueListenable: _controller.progress,
            builder: (_, p, __) => p < 1.0 ? LinearProgressIndicator(value: p) : const SizedBox.shrink(),
          ),

          // WebView
          Expanded(
            child: FixitWebView(controller: _controller, config: _config),
          ),

          // Nav bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.canGoBack,
                    builder: (_, can, __) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: can ? () => _controller.goBack() : null),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.canGoForward,
                    builder: (_, can, __) => IconButton(icon: const Icon(Icons.arrow_forward), onPressed: can ? () => _controller.goForward() : null),
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
                  IconButton(icon: const Icon(Icons.stop), tooltip: 'Stop Loading', onPressed: () => _controller.stopLoading()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
