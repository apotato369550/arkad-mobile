import 'package:flutter/services.dart' show rootBundle;

final Map<String, String> _promptCache = {};

/// Loads a prompt template from `assets/prompts/<name>.md`, caching it after
/// the first read since the bundled asset never changes at runtime.
Future<String> loadPromptTemplate(String name) async {
  return _promptCache[name] ??=
      (await rootBundle.loadString('assets/prompts/$name.md')).trimRight();
}

/// Loads the named template and replaces every `{{key}}` placeholder with
/// the matching value from [vars].
Future<String> renderPrompt(String name, Map<String, String> vars) async {
  var text = await loadPromptTemplate(name);
  for (final entry in vars.entries) {
    text = text.replaceAll('{{${entry.key}}}', entry.value);
  }
  return text;
}
