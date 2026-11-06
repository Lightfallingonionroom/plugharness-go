import 'package:dsh_app/state/scene_accounts_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  SceneAccount account() => SceneAccount(
    id: 'acct-0123456789abcdef', name: 'Coding', createdAt: now, updatedAt: now,
    model: const ModelSelection(provider: 'deepseek', model: 'v4', reasoningEffort: 'high'),
    petId: 'deepy-whale', host: '{"kind":"local","id":"local"}',
  );

  test('scene record round trip contains configuration, never credentials', () {
    final decoded = SceneAccount.parse(account().toJson());
    expect(decoded, isNotNull);
    expect(decoded!.name, 'Coding');
    expect(decoded.model?.reasoningEffort, 'high');
    expect(decoded.petId, 'deepy-whale');
    expect(decoded.toJson().toString(), isNot(contains('apiKey')));
  });

  test('unsafe ids and missing/invalid records are rejected', () {
    expect(SceneAccount.parse({...account().toJson(), 'id': '../other'}), isNull);
    expect(SceneAccount.parse({...account().toJson(), 'name': ''}), isNull);
    expect(SceneAccount.parse('broken'), isNull);
  });
}