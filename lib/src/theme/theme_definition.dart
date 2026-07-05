/// Defines a named theme with associated CSS that can be injected into the
/// WebView page.
class ThemeDefinition {
  /// A human-readable name for this theme (e.g. 'dark_auto').
  final String name;

  /// The CSS string to inject into the page.
  final String css;

  /// Creates a [ThemeDefinition] with the given [name] and [css].
  const ThemeDefinition({required this.name, required this.css});
}
