// The preset table is data, not UI: these tests pin the invariants that keep
// auto-fill safe (no duplicate ids, no empty endpoints, protocols the host
// actually speaks, and a stable lookup).

import 'package:dsh_app/state/provider_presets.dart';
import 'package:dsh_client/dsh_client.dart' show ProviderApi;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset has a unique id and a usable endpoint', () {
    final ids = providerPresets.map((p) => p.id).toSet();
    expect(ids.length, providerPresets.length, reason: 'no duplicate preset ids');
    for (final p in providerPresets) {
      expect(p.name, isNotEmpty, reason: '${p.id} needs a label');
      expect(p.endpoint, startsWith('http'), reason: '${p.id} needs a full URL');
      expect(Uri.tryParse(p.endpoint)?.host, isNotEmpty, reason: '${p.id} endpoint must parse');
    }
  });

  test('presets only use protocols the engine exposes', () {
    const allowed = {
      ProviderApi.openaiCompletions,
      ProviderApi.anthropicMessages,
      ProviderApi.openaiResponses,
    };
    for (final p in providerPresets) {
      expect(allowed, contains(p.api), reason: '${p.id} asks for an unsupported protocol');
    }
  });

  test('local presets need no key; endpoint variants stay valid', () {
    for (final p in providerPresets) {
      if (p.endpoint.contains('localhost')) {
        expect(p.requiresKey, isFalse, reason: '${p.id} is a local endpoint');
      }
      for (final option in p.endpointOptions) {
        expect(option.url, startsWith('http'), reason: '${p.id}/${option.label}');
        expect(option.label, isNotEmpty);
      }
    }
  });

  test('lookup is stable and custom/unknown ids resolve to null', () {
    for (final p in providerPresets) {
      final found = providerPreset(p.id);
      expect(found, isNotNull, reason: '${p.id} must resolve');
      expect(found!.id, p.id);
      expect(found.endpoint, p.endpoint);
    }
    expect(providerPreset(null), isNull);
    expect(providerPreset('not-a-provider'), isNull);
  });

  test('well-known providers carry their public base URLs', () {
    expect(providerPreset('openai')!.endpoint, 'https://api.openai.com/v1');
    expect(providerPreset('deepseek')!.endpoint, 'https://api.deepseek.com/v1');
    expect(providerPreset('anthropic')!.api, ProviderApi.anthropicMessages);
    expect(providerPreset('ollama')!.requiresKey, isFalse);
  });

  test('remote presets require a key and suggest a first model', () {
    for (final p in providerPresets) {
      if (p.endpoint.contains('localhost')) continue;
      expect(p.requiresKey, isTrue, reason: '${p.id} is a remote endpoint');
      expect(p.defaultModel, isNotEmpty, reason: '${p.id} should suggest a model');
    }
  });
}