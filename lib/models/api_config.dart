const String defaultModelSlug = 'inclusionai/ling-3.0-tiny:free';

/// Curated list of known free-tier ':free' OpenRouter model slugs.
/// Kept short and conservative — only slugs we're confident actually
/// exist/existed on OpenRouter's free tier are listed here. Users can
/// still enter any arbitrary slug via the "Custom" option in Settings.
const List<String> knownFreeModelSlugs = [
  defaultModelSlug,
  'meta-llama/llama-3.3-70b-instruct:free',
  'google/gemma-2-9b-it:free',
  'mistralai/mistral-7b-instruct:free',
  'qwen/qwen-2.5-72b-instruct:free',
  'deepseek/deepseek-r1:free',
];

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
