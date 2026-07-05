import 'dart:async';
import 'package:flutter/material.dart';
import '../config/fixit_theme_config.dart';
import 'theme_definition.dart';

/// Injects and manages CSS themes into a WebView page by evaluating
/// JavaScript to add or remove `<style>` elements.
class FixitThemeEngine {
  /// Callback that evaluates JavaScript in the WebView context.
  final Future<void> Function(String) evaluateJavascript;

  ThemeDefinition? _currentTheme;
  final ValueNotifier<ThemeDefinition?> _themeNotifier =
      ValueNotifier<ThemeDefinition?>(null);
  FixitThemeConfig? _config;
  Brightness? _lastBrightness;
  bool _autoDetect = true;
  bool _disposed = false;

  /// Creates a [FixitThemeEngine] with the given [evaluateJavascript] callback.
  FixitThemeEngine({required this.evaluateJavascript});

  // ── Public API ──────────────────────────────────────────────────────────

  /// The currently active [ThemeDefinition], or `null` if none.
  ThemeDefinition? get currentTheme => _currentTheme;

  /// A [ValueNotifier] that emits the current [ThemeDefinition] on changes.
  ValueNotifier<ThemeDefinition?> get theme => _themeNotifier;

  /// The last applied [FixitThemeConfig], or `null`.
  FixitThemeConfig? get config => _config;

  /// Whether the engine automatically adapts to system brightness changes.
  bool get autoDetect => _autoDetect;

  /// Enables or disables automatic brightness detection. When enabled and a
  /// [FixitThemeConfig] has been applied, the theme adapts to brightness.
  set autoDetect(bool value) {
    _autoDetect = value;
    if (value && _config != null && _lastBrightness != null) {
      applyConfig(_config!);
    }
  }

  /// The last system brightness reported via [notifyBrightness].
  Brightness? get lastBrightness => _lastBrightness;

  /// Called by the widget when system brightness changes.
  void notifyBrightness(Brightness brightness) {
    if (_lastBrightness == brightness) return;
    _lastBrightness = brightness;
    if (_autoDetect && _config != null) {
      applyConfig(_config!);
    }
  }

  /// Applies a theme config (generates CSS from colors + brightness).
  Future<void> applyConfig(FixitThemeConfig config) async {
    _config = config;
    final brightness = _autoDetect
        ? (_lastBrightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness)
        : (config.preferredBrightness ?? Brightness.light);
    final themeDef = config.toThemeDefinition(brightness);
    await injectTheme(themeDef);
  }

  /// Injects a [theme] into the WebView page by creating a `<style>` element.
  Future<void> injectTheme(ThemeDefinition theme) async {
    if (_disposed) return;
    _currentTheme = theme;
    _themeNotifier.value = theme;
    final escaped = theme.css
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
    await evaluateJavascript("""
      (function() {
        var e = document.getElementById('fixit-theme');
        if (e) e.remove();
        var s = document.createElement('style');
        s.id = 'fixit-theme';
        s.textContent = '$escaped';
        document.head.appendChild(s);
      })();
    """);
  }

  /// Removes the injected theme from the WebView page and resets state.
  Future<void> resetTheme() async {
    if (_disposed) return;
    _currentTheme = null;
    _themeNotifier.value = null;
    _config = null;
    await evaluateJavascript(
      "document.getElementById('fixit-theme')?.remove()",
    );
  }

  /// Releases the [ValueNotifier] and marks the engine as disposed.
  void dispose() {
    _disposed = true;
    _themeNotifier.dispose();
  }
}
