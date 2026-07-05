/// An adapter interface for integrating AI-powered features such as page
/// analysis and CSS selector suggestions.
abstract class FixitAIAdapter {
  /// Analyzes the HTML content of a page and returns an AI-generated summary
  /// or analysis result.
  Future<String> analyzePage(String htmlContent);

  /// Suggests CSS selectors relevant to the given natural language [query].
  Future<List<String>> suggestCssSelectors(String query);
}
