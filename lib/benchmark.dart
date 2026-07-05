/// Benchmark API for the Fixit Runtime SDK.
///
/// This library exports diagnostic and timeline models used by the benchmark tool.
/// It is intentionally NOT exported from `fixit_webview.dart` to avoid polluting
/// the public SDK API.
///
/// Import this via:
/// `import 'package:fixit_webview/benchmark.dart';`
library fixit_webview.benchmark;

export 'src/internal/diagnostics_models.dart';
