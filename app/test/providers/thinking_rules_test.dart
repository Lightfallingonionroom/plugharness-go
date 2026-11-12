// Thinking rules: the rule layer is a pure function of the model selection.
// These tests pin matching, order, manual override and the Host-facing seam.

import 'package:dsh_app/state/thinking_rules_state.dart';
import 'package:dsh_client/dsh_client.dart' show ModelSelection;
import 'package:flutter_test/flutter_test.dart';

ModelSelection _sel(String provider, String model, [String? effort]) =>
    ModelSelection(provider: provider, model: model, reasoningEffort: effort);

ThinkingRule _rule(
  String provider,
  String model,
  String effort, {
  String id = 'r',
  ThinkingRuleMode mode = ThinkingRuleMode.always,
  bool enabled = true,
}) =>
    ThinkingRule(
      id: id,
      provider: provider,
      model: model,
      effort: effort,
      mode: mode,
      enabled: enabled,
    );

void main() {
  test('glob matching keeps the historical wildcard forms', () {
    final prefix = _rule('*', 'deepseek-*', 'high');
    expect(prefix.matches(_sel('deepseek-official', 'deepseek-v4-pro')), isTrue);
    expect(prefix.matches(_sel('deepseek-official', 'qwen-max')), isFalse);
    expect(_rule('deepseek-official', '*', 'low').matches(_sel('deepseek-official', 'anything')), isTrue);
    expect(_rule('*', 'exact-model', 'low').matches(_sel('p', 'exact-model')), isTrue);
    expect(_rule('*', 'exact-model', 'low').matches(_sel('p', 'other')), isFalse);
  });

  test('suffix, contains and mid-glob patterns match by segment', () {
    expect(_rule('*', '*pro', 'high').matches(_sel('p', 'deepseek-v4-pro')), isTrue);
    expect(_rule('*', '*pro', 'high').matches(_sel('p', 'pro-log')), isFalse);
    expect(_rule('*', '*4o*', 'medium').matches(_sel('p', 'gpt-4o-mini')), isTrue);
    expect(_rule('*', 'gpt*mini', 'medium').matches(_sel('p', 'gpt-4o-mini')), isTrue);
    expect(_rule('*', 'gpt*mini', 'medium').matches(_sel('p', 'gpt-mini-4o')), isTrue);
    expect(_rule('*', 'gpt*mini', 'medium').matches(_sel('p', 'mini-gpt')), isFalse);
    expect(_rule('', '', 'low').matches(_sel('anything', 'whatever')), isTrue);
  });

  test('matching is case-insensitive for provider and model ids', () {
    expect(_rule('DeepSeek-*', 'DeepSeek-*', 'high').matches(_sel('deepseek-official', 'deepseek-v4')), isTrue);
  });

  test('first enabled matching rule wins; disabled rules are skipped', () {
    final state = ThinkingRulesState(
      rules: [
        _rule('*', '*', 'off', id: 'a', enabled: false),
        _rule('*', 'deepseek-*', 'high', id: 'b'),
        _rule('*', '*', 'low', id: 'c'),
      ],
      fallbackEffort: 'medium',
    );
    expect(state.evaluate(_sel('p', 'deepseek-v4')), 'high');
    expect(state.evaluate(_sel('p', 'qwen-max')), 'low');
  });

  test('manual mode never overrides a manual pick; always mode still applies', () {
    final manual = ThinkingRulesState(rules: [_rule('*', '*', 'high', mode: ThinkingRuleMode.manual)]);
    expect(manual.evaluate(_sel('p', 'm'), hasManualPick: false), 'high');
    expect(manual.evaluate(_sel('p', 'm'), hasManualPick: true), isNull);
    final always = ThinkingRulesState(rules: [_rule('*', '*', 'high')]);
    expect(always.evaluate(_sel('p', 'm'), hasManualPick: true), 'high');
  });

  test('applyThinkingRules is the only seam and is a no-op when unchanged', () {
    final state = ThinkingRulesState(rules: [_rule('deepseek-official', '*', 'high')]);
    final original = _sel('deepseek-official', 'deepseek-v4-pro', 'low');
    final changed = applyThinkingRules(original, state);
    expect(changed.reasoningEffort, 'high');
    expect(changed.provider, original.provider);
    expect(changed.model, original.model);

    final same = _sel('deepseek-official', 'deepseek-v4-pro', 'high');
    expect(identical(applyThinkingRules(same, state), same), isTrue);
    final untouched = _sel('other', 'm');
    expect(identical(applyThinkingRules(untouched, ThinkingRulesState()), untouched), isTrue);
  });

  test('unknown effort strings are never invented: fallback is explicit', () {
    final state = ThinkingRulesState(rules: const [], fallbackEffort: null);
    final original = _sel('p', 'm', 'unknown');
    expect(identical(applyThinkingRules(original, state), original), isTrue);
  });

  test('JSON round-trip keeps order, mode and enabled', () {
    final rule = _rule('deepseek-*', '*pro*', 'max', id: 'x', mode: ThinkingRuleMode.manual, enabled: false);
    final restored = ThinkingRule.fromJson(rule.toJson());
    expect(restored, isNotNull);
    expect(restored!.id, rule.id);
    expect(restored.provider, rule.provider);
    expect(restored.model, rule.model);
    expect(restored.effort, rule.effort);
    expect(restored.mode, ThinkingRuleMode.manual);
    expect(restored.enabled, isFalse);
    expect(ThinkingRule.fromJson({'id': 1}), isNull);
  });
}