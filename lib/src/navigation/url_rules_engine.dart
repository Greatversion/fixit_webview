/// A rule that matches URLs against a [RegExp] pattern and routes them to a
/// named destination (e.g. 'native', 'webview', 'external').
class UrlRule {
  /// The regular expression pattern used to match URLs.
  final RegExp pattern;

  /// The route destination for URLs matching [pattern].
  final String route;

  /// Creates a [UrlRule] with the given [pattern] and [route].
  UrlRule({required this.pattern, required this.route});
}

/// Evaluates URLs against a list of [UrlRule]s to determine how they should
/// be handled (e.g. rendered in the WebView, opened natively, or blocked).
class FixitUrlRulesEngine {
  final List<UrlRule> _rules = [];

  /// Adds a rule that routes URLs matching [regex] to the given [route].
  void addRule(String regex, String route) {
    _rules.add(UrlRule(pattern: RegExp(regex), route: route));
  }

  /// Matches [url] against all registered rules and returns the matching
  /// route, or `'webview'` if no rule matches.
  String match(String url) {
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(url)) {
        return rule.route;
      }
    }
    return 'webview'; // Default to webview rendering
  }
}
