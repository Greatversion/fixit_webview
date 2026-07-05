import 'package:flutter/material.dart';
import '../theme/theme_definition.dart';

/// Holds color and brightness configuration for generating CSS themes that
/// can be injected into a WebView page.
class FixitThemeConfig {
  /// The background color to use, or `null` for a platform default.
  final Color? backgroundColor;

  /// The text color to use, or `null` for a platform default.
  final Color? textColor;

  /// The accent/highlight color to use, or `null` for a platform default.
  final Color? accentColor;

  /// The surface/card color to use, or `null` for a platform default.
  final Color? surfaceColor;

  /// The preferred [Brightness] (light/dark), or `null` for auto-detection.
  final Brightness? preferredBrightness;

  /// Creates a [FixitThemeConfig] with optional color overrides.
  const FixitThemeConfig({
    this.backgroundColor,
    this.textColor,
    this.accentColor,
    this.surfaceColor,
    this.preferredBrightness,
  });

  /// Generates a CSS string for the given [effectiveBrightness].
  String toCss(Brightness effectiveBrightness) {
    final isDark = preferredBrightness == Brightness.dark ||
        (preferredBrightness == null && effectiveBrightness == Brightness.dark);

    final bg = _colorCss(backgroundColor ??
        (isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF)));
    final text = _colorCss(textColor ??
        (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A)));
    final accent = _colorCss(accentColor ??
        (isDark ? const Color(0xFFBB86FC) : const Color(0xFF6200EE)));
    final surface = _colorCss(surfaceColor ??
        (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5)));

    return '''
:root {
  --fixit-bg: $bg;
  --fixit-text: $text;
  --fixit-accent: $accent;
  --fixit-surface: $surface;
}
body {
  background-color: $bg !important;
  color: $text !important;
}
h1, h2, h3, p, span, div, li {
  color: $text !important;
}
a { color: $accent !important; }
''';
  }

  /// Converts this config into a [ThemeDefinition] using the given
  /// [effectiveBrightness] to determine light/dark defaults.
  ThemeDefinition toThemeDefinition(Brightness effectiveBrightness) {
    final isDark = preferredBrightness == Brightness.dark ||
        (preferredBrightness == null && effectiveBrightness == Brightness.dark);
    return ThemeDefinition(
      name: isDark ? 'dark_auto' : 'light_auto',
      css: toCss(effectiveBrightness),
    );
  }

  static String _colorCss(Color c) =>
      'rgb(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()})';
}

/// A builder for constructing [FixitThemeConfig] instances using a fluent API.
class FixitThemeConfigBuilder {
  Color? _backgroundColor;
  Color? _textColor;
  Color? _accentColor;
  Color? _surfaceColor;
  Brightness? _preferredBrightness;

  /// Sets the background [color] and returns this builder.
  FixitThemeConfigBuilder setBackgroundColor(Color color) {
    _backgroundColor = color;
    return this;
  }

  /// Sets the text [color] and returns this builder.
  FixitThemeConfigBuilder setTextColor(Color color) {
    _textColor = color;
    return this;
  }

  /// Sets the accent [color] and returns this builder.
  FixitThemeConfigBuilder setAccentColor(Color color) {
    _accentColor = color;
    return this;
  }

  /// Sets the surface [color] and returns this builder.
  FixitThemeConfigBuilder setSurfaceColor(Color color) {
    _surfaceColor = color;
    return this;
  }

  /// Sets the preferred [brightness] and returns this builder.
  FixitThemeConfigBuilder setPreferredBrightness(Brightness brightness) {
    _preferredBrightness = brightness;
    return this;
  }

  /// Builds and returns the [FixitThemeConfig] with the configured values.
  FixitThemeConfig build() => FixitThemeConfig(
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        accentColor: _accentColor,
        surfaceColor: _surfaceColor,
        preferredBrightness: _preferredBrightness,
      );
}
