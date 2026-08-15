const String defaultModelSlug = 'openrouter/free';

/// The only preset model slug offered in Settings. Users can still enter
/// any arbitrary slug via the "Custom" option.
const List<String> knownFreeModelSlugs = [defaultModelSlug];

class ApiConfig {
  ApiConfig({this.apiKey, this.modelSlug = defaultModelSlug});

  final String? apiKey;
  final String modelSlug;

  bool get hasKey => apiKey != null && apiKey!.trim().isNotEmpty;

  ApiConfig copyWith({String? apiKey, bool clearKey = false, String? modelSlug}) {
    return ApiConfig(
      apiKey: clearKey ? null : (apiKey ?? this.apiKey),
      modelSlug: modelSlug ?? this.modelSlug,
    );
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      apiKey: json['apiKey'] as String?,
      modelSlug: json['modelSlug'] as String? ?? defaultModelSlug,
    );
  }

  Map<String, dynamic> toJson() => {'apiKey': apiKey, 'modelSlug': modelSlug};
}
