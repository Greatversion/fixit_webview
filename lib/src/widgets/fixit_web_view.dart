import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../controller/fixit_web_view_controller.dart';
import '../config/fixit_runtime_config.dart';
import '../internal/startup_registry.dart';

/// A Flutter widget that embeds a native platform WebView (Android / iOS) and
/// provides production-grade features such as crash recovery, white-flash
/// prevention, pull-to-refresh, diagnostics, and theme injection.
///
/// Use [FixitWebViewController] to control the WebView programmatically.
class FixitWebView extends StatefulWidget {
  /// The controller that manages navigation, JavaScript execution, and other
  /// WebView operations.
  final FixitWebViewController controller;

  /// Optional runtime configuration that enables diagnostics, crash recovery,
  /// white-flash prevention, and other advanced features.
  /// Normal SDK users do NOT need to pass this.
  final FixitRuntimeConfig? config;

  /// Callback invoked when the user triggers a pull-to-refresh gesture.
  /// If null and [FixitRuntimeConfig.enablePullToRefresh] is true, the
  /// controller's [FixitWebViewController.refresh] is used.
  final Future<void> Function()? onRefresh;

  /// Creates a [FixitWebView] with the given [controller] and optional
  /// [config] and [onRefresh] callback.
  const FixitWebView({
    Key? key,
    required this.controller,
    this.config,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<FixitWebView> createState() => _FixitWebViewState();
}

class _FixitWebViewState extends State<FixitWebView>
    with WidgetsBindingObserver {
  bool _webViewVisible = true;
  bool _showSplash = false;
  bool _isCrashed = false;
  double _webViewOpacity = 1.0;
  double _splashOpacity = 1.0;
  bool _isLoading = false;
  double _currentProgress = 0.0;
  StreamSubscription<WebViewCrashEvent>? _crashSub;
  StreamSubscription<void>? _restartSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cfg = widget.config;
    if (cfg?.whiteFlashPrevention == true) {
      _webViewVisible = false;
      _showSplash = true;
      _webViewOpacity = 0.0;
      _splashOpacity = 1.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cfg?.themeConfig != null) {
        widget.controller.themeEngine.applyConfig(cfg!.themeConfig!);
      }
      _setupProductionFeatures();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        widget.controller.pause();
      case AppLifecycleState.resumed:
        widget.controller.resume();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _setupProductionFeatures() {
    final ctrl = widget.controller;
    final cfg = widget.config;

    // White flash prevention: show splash until first paint
    if (cfg?.whiteFlashPrevention == true) {
      ctrl.onFirstPaint.addListener(_onFirstPaint);
    }

    // Custom loader: track loading state for overlay
    if (cfg?.loaderBuilder != null) {
      ctrl.loading.addListener(_onLoadingChanged);
      ctrl.progress.addListener(_onProgressChanged);
    }

    // Crash recovery: auto-restart WebView on renderer crash
    if (cfg?.enableCrashRecovery == true) {
      _crashSub = ctrl.onCrash.listen((_) => _recoverFromCrash());
      _restartSub = ctrl.onRestart.listen((_) {
        if (mounted) {
          _isCrashed = false;
          _webViewVisible = true;
          setState(() {});
        }
      });
    }
  }

  void _onFirstPaint() {
    if (!mounted) return;
    final duration = widget.config?.splashTransitionDuration ??
        const Duration(milliseconds: 300);
    setState(() {
      _webViewOpacity = 1.0;
      _splashOpacity = 0.0;
      _webViewVisible = true;
    });
    Future.delayed(duration, () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  void _onLoadingChanged() {
    if (!mounted) return;
    setState(() {
      _isLoading = widget.controller.loading.value;
    });
  }

  void _onProgressChanged() {
    if (!mounted) return;
    setState(() {
      _currentProgress = widget.controller.progress.value;
    });
  }

  Future<void> _recoverFromCrash() async {
    if (!mounted) return;
    setState(() {
      _isCrashed = true;
      _webViewVisible = false;
    });
    // Reload the last known URL
    final url = widget.controller.currentUrl.value;
    if (url != null) {
      await widget.controller.loadUrl(url);
    } else {
      await widget.controller.reload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.onFirstPaint.removeListener(_onFirstPaint);
    widget.controller.loading.removeListener(_onLoadingChanged);
    widget.controller.progress.removeListener(_onProgressChanged);
    _crashSub?.cancel();
    _restartSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final cfg = widget.config;

    ctrl.themeEngine.notifyBrightness(MediaQuery.platformBrightnessOf(context));
    final diagnosticsEnabled = cfg?.diagnosticsEnabled ?? false;

    if (diagnosticsEnabled) {
      fixitStartupRegistry.markT0(ctrl.viewId);
    }

    const String viewType = 'com.fixit.fixit_webview/view';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'viewId': ctrl.viewId,
      if (diagnosticsEnabled) 'diagnosticsLevel': cfg!.diagnosticsLevel!.name,
    };

    Widget webView;
    if (Platform.isAndroid) {
      webView = PlatformViewLink(
        viewType: viewType,
        surfaceFactory:
            (BuildContext context, PlatformViewController controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () {
              params.onFocusChanged(true);
            },
          )
            ..addOnPlatformViewCreatedListener((id) {
              ctrl.initializeEventChannel();
              params.onPlatformViewCreated(id);
            })
            ..create();
        },
      );
    } else if (Platform.isIOS) {
      webView = UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (_) {
          ctrl.initializeEventChannel();
        },
      );
    } else {
      return Center(
        child: Text(
            'Platform ${Platform.operatingSystem} is not supported by FixitWebView.'),
      );
    }

    // White flash prevention: animated fade from splash to WebView
    if (cfg?.whiteFlashPrevention == true) {
      final transitionDuration = cfg!.splashTransitionDuration;

      webView = AnimatedOpacity(
        opacity: _webViewOpacity,
        duration: transitionDuration,
        child: webView,
      );

      webView = Stack(
        children: [
          if (_webViewVisible || _showSplash) webView,
          if (_showSplash)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _splashOpacity,
                duration: transitionDuration,
                child: cfg.splashBuilder?.call(context) ??
                    _defaultSplash(context),
              ),
            ),
        ],
      );
    }

    // Custom loader: overlay during page navigation
    final loaderBuilder = cfg?.loaderBuilder;
    if (loaderBuilder != null) {
      webView = Stack(
        children: [
          webView,
          if (_isLoading)
            Positioned.fill(
              child: loaderBuilder(context, _currentProgress),
            ),
        ],
      );
    }

    // Crash recovery UI: overlay when renderer crashes
    if (_isCrashed && cfg?.enableCrashRecovery == true) {
      webView = Stack(
        children: [
          webView,
          Positioned.fill(
            child: cfg?.crashOverlayBuilder?.call(context) ??
                _defaultCrashOverlay(context),
          ),
        ],
      );
    }

    // Pull-to-refresh: wrap with RefreshIndicator
    final onRefresh = widget.onRefresh ??
        (cfg?.enablePullToRefresh == true ? ctrl.refresh : null);
    if (onRefresh != null) {
      webView = RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height + 1,
            child: webView,
          ),
        ),
      );
    }

    return webView;
  }

  Widget _defaultSplash(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _defaultCrashOverlay(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page crashed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong while loading the page.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final url = widget.controller.currentUrl.value;
                if (url != null) {
                  await widget.controller.loadUrl(url);
                } else {
                  await widget.controller.reload();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }
}
