// Provider presets: the "auto-fill the API address" table.
//
// Principle borrowed from Operit's `ApiProviderConfigs` (LGPL-3.0, read only):
// one row per provider carrying a protocol, a default endpoint, optional
// endpoint variants, a default model and whether a key is required. No code
// is copied; the values here are public endpoint URLs, and the shape is ours.
//
// Deliberately smaller than Operit's 30+ rows: this app's engine exposes only
// three wire protocols (openaiCompletions / anthropicMessages /
// openaiResponses), so a preset must never imply a protocol the host cannot
// speak. Anything not listed stays a fully custom provider.

import 'package:dsh_client/dsh_client.dart' show ProviderApi;

/// One alternative endpoint for the same provider.
class ProviderEndpointOption {
  const ProviderEndpointOption(this.url, this.label);

  final String url;
  final String label;
}

/// A row of the preset table.
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.name,
    required this.api,
    required this.endpoint,
    this.endpointOptions = const [],
    this.defaultModel = '',
    this.requiresKey = true,
  });

  /// Stable id; also used as the suggested route slug when the name is empty.
  final String id;
  final String name;
  final ProviderApi api;

  /// The address filled into an empty Base URL field.
  final String endpoint;

  /// Optional variants the user can pick explicitly.
  final List<ProviderEndpointOption> endpointOptions;

  /// Suggested first model id. Never overwrites a model list the user built.
  final String defaultModel;

  /// Local/keyless endpoints do not need an API key.
  final bool requiresKey;
}

/// The presets, in the order shown in the picker.
///
/// Endpoints are the public base URLs; discovery (`/v1` fallback) stays the
/// single place that repairs a bare host, so a preset must not duplicate it.
const providerPresets = <ProviderPreset>[
  ProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o',
  ),
  ProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-chat',
  ),
  ProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    api: ProviderApi.anthropicMessages,
    endpoint: 'https://api.anthropic.com/v1',
    defaultModel: 'claude-sonnet-4-5',
  ),
  ProviderPreset(
    id: 'google',
    name: 'Google Gemini',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai',
    defaultModel: 'gemini-2.0-flash',
  ),
  ProviderPreset(
    id: 'moonshot',
    name: 'Moonshot / Kimi',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://api.moonshot.cn/v1',
    endpointOptions: [
      ProviderEndpointOption('https://api.moonshot.cn/v1', 'China'),
      ProviderEndpointOption('https://api.moonshot.ai/v1', 'International'),
    ],
    defaultModel: 'moonshot-v1-8k',
  ),
  ProviderPreset(
    id: 'zhipu',
    name: 'Zhipu / GLM',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://open.bigmodel.cn/api/paas/v4',
    endpointOptions: [
      ProviderEndpointOption('https://open.bigmodel.cn/api/paas/v4', 'China'),
      ProviderEndpointOption('https://api.z.ai/api/paas/v4', 'International'),
    ],
    defaultModel: 'glm-4.5',
  ),
  ProviderPreset(
    id: 'aliyun',
    name: 'Aliyun / Qwen',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen-max',
  ),
  ProviderPreset(
    id: 'doubao',
    name: 'Doubao',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModel: 'doubao-pro-32k',
  ),
  ProviderPreset(
    id: 'siliconflow',
    name: 'SiliconFlow',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://api.siliconflow.cn/v1',
    defaultModel: 'Qwen/Qwen2.5-7B-Instruct',
  ),
  ProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    api: ProviderApi.openaiCompletions,
    endpoint: 'https://openrouter.ai/api/v1',
    defaultModel: 'openai/gpt-4o-mini',
  ),
  ProviderPreset(
    id: 'ollama',
    name: 'Ollama (local)',
    api: ProviderApi.openaiCompletions,
    endpoint: 'http://localhost:11434/v1',
    requiresKey: false,
  ),
  ProviderPreset(
    id: 'lmstudio',
    name: 'LM Studio (local)',
    api: ProviderApi.openaiCompletions,
    endpoint: 'http://localhost:1234/v1',
    defaultModel: 'local-model',
    requiresKey: false,
  ),
];

/// Lookup by id, or null for a custom provider.
ProviderPreset? providerPreset(String? id) {
  if (id == null) return null;
  for (final p in providerPresets) {
    if (p.id == id) return p;
  }
  return null;
}