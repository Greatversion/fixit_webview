class FixitWebViewState {
  final String url;
  final bool loading;
  final double progress;
  final List<String> history;
  final List<String> cookies;
  final List<String> errors;

  FixitWebViewState({
    required this.url,
    required this.loading,
    required this.progress,
    required this.history,
    required this.cookies,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'loading': loading,
        'progress': progress,
        'history': history,
        'cookies': cookies,
        'errors': errors,
      };

  factory FixitWebViewState.fromJson(Map<String, dynamic> json) {
    return FixitWebViewState(
      url: json['url'] as String? ?? '',
      loading: json['loading'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      history: (json['history'] as List?)?.cast<String>() ?? [],
      cookies: (json['cookies'] as List?)?.cast<String>() ?? [],
      errors: (json['errors'] as List?)?.cast<String>() ?? [],
    );
  }
}
