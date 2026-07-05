import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fixit_core/fixit_core.dart';
import 'package:fixit_webview/fixit_webview.dart';
// Use the new public-facing benchmark API instead of importing from src/internal
import 'package:fixit_webview/benchmark.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixit Benchmark',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.dark,
        ),
      ),
      home: const BenchmarkScreen(),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final FixitLogger _logger;
  late final FixitEventBus _eventBus;
  late final FixitRuntimeContext _runtimeContext;
  late final FixitRuntime _runtime;
  late final FixitWebViewController _controller;
  late final FixitRuntimeConfig _config;

  final TextEditingController _urlInputController =
      TextEditingController(text: 'https://flutter.dev');
  bool _initialized = false;
  StartupTimelineEvent? _lastTimeline;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  void _initEngine() {
    _logger = FixitLogger(label: 'BenchmarkApp');
    _eventBus = FixitEventBus();

    _runtimeContext = FixitRuntimeContext(
      logger: _logger,
      cache: FixitCacheManager(),
      cookies: FixitCookieManager(),
      session: FixitSessionManager(),
      events: _eventBus,
    );

    _runtime = FixitRuntime.create(1, _runtimeContext);
    _controller = FixitWebViewController(_runtime);

    _config = FixitRuntimeConfig.builder()
        .setInitialUrl(_urlInputController.text)
        .enablePooling()
        .enableBridge()
        // ENABLE DIAGNOSTICS FOR BENCHMARKING
        .enableDiagnostics(level: DiagnosticsLevel.verbose)
        .build();

    // Listen to diagnostics stream to capture the startup timeline
    _controller.diagnosticsStream.listen((event) {
      setState(() {
        _lastTimeline = event;
      });
      _logger.error('Received startup timeline:\n${event.rawTimeline}');
    });

    _runtime.initialize(_config).then((_) {
      setState(() {
        _initialized = true;
      });
    });
  }

  @override
  void dispose() {
    _runtime.dispose();
    _eventBus.dispose();
    _urlInputController.dispose();
    super.dispose();
  }

  Future<void> _exportTimeline() async {
    if (_lastTimeline == null) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/benchmark_timeline_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(_lastTimeline!.toJson()));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Timeline exported to: ${file.path}')),
        );
      }
    } catch (e) {
      _logger.error('Failed to export timeline: $e');
    }
  }

  void _showTimelineDialog() {
    if (_lastTimeline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No timeline recorded yet.')),
      );
      return;
    }

    // Generate JSON preview
    final jsonPreview = const JsonEncoder.withIndent('  ').convert(_lastTimeline!.toJson());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Startup Timeline Preview'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_lastTimeline!.totalStartupDuration != null)
                  Text(
                    'Total Startup: ${_lastTimeline!.totalStartupDuration!.inMilliseconds} ms',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const Divider(),
                const Text('Raw Timeline:'),
                Text(_lastTimeline!.rawTimeline, style: const TextStyle(fontSize: 12)),
                const Divider(),
                const Text('JSON Data:'),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black26,
                  child: Text(jsonPreview, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _exportTimeline(); // Export triggered explicitly by user
              },
              child: const Text('Save File'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixit Benchmark'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Preview Timeline',
            onPressed: _showTimelineDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlInputController,
                    decoration: const InputDecoration(
                      hintText: 'Enter URL',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (url) {
                      _controller.loadUrl(url);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _controller.loadUrl(_urlInputController.text);
                  },
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _controller.progress,
            builder: (context, progress, child) {
              if (progress >= 1.0) return const SizedBox.shrink();
              return LinearProgressIndicator(value: progress);
            },
          ),
          Expanded(
            child: Container(
              color: Colors.black12,
              child: FixitWebView(
                controller: _controller,
                config: _config, // Important: pass config so widget logs T0
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.canGoBack,
                    builder: (context, canGoBack, child) {
                      return IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: canGoBack ? () => _controller.goBack() : null,
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.canGoForward,
                    builder: (context, canGoForward, child) {
                      return IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: canGoForward ? () => _controller.goForward() : null,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller.reload(),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.loading,
                    builder: (context, loading, child) {
                      return loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done_outlined, color: Colors.green);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
