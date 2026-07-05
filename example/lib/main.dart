import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BasicExampleApp(),
  ));
}

class BasicExampleApp extends StatefulWidget {
  const BasicExampleApp({super.key});

  @override
  State<BasicExampleApp> createState() => _BasicExampleAppState();
}

class _BasicExampleAppState extends State<BasicExampleApp> {
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    // 1. Create minimal runtime context
    final runtimeContext = FixitRuntimeContext(
      logger: FixitLogger(label: 'BasicExample'),
      events: FixitEventBus(),
      cache: FixitCacheManager(),
      cookies: FixitCookieManager(),
      session: FixitSessionManager(),
    );

    // 2. Create runtime instance and controller
    _runtime = FixitRuntime.create(1, runtimeContext);
    _controller = FixitWebViewController(_runtime);

    // 3. Configure and initialize (No diagnostics/benchmarking enabled)
    final config = FixitRuntimeConfig.builder()
        .setInitialUrl('https://flutter.dev')
        .build();

    await _runtime.initialize(config);
    
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixit WebView Basic')),
      body: _isReady 
          ? FixitWebView(controller: _controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
