const String defaultModelSlug = 'openai/gpt-4o-mini';

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
