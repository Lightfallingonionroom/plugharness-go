// 思考配置：按模型分别配置推理强度的规则层。
//
// DSH 原生只有一个全局 `ModelSelection.reasoningEffort`；换模型时它不跟着变，
// 而每个模型支持的档位（model.efforts）又不一样。这一层补的是「规则列表」：
// 可排序、可启停、首条命中生效，未命中走兜底。
//
// **不造第二条链路**：规则求值的结果只是覆盖 `ModelSelection.reasoningEffort`，
// 由调用方在发消息前 setModel()，和模型弹窗、引擎设置页完全同一条路。

import 'dart:convert';

import 'package:dsh_client/dsh_client.dart' show ModelSelection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 规则的触发方式。
enum ThinkingRuleMode {
  /// 每次发消息都按这条规则求值。
  always,

  /// 只在用户手动选过档位时生效（保留用户的选择，不覆盖）。
  manual,
}

/// 一条思考配置规则。
class ThinkingRule {
  const ThinkingRule({
    required this.id,
    required this.provider,
    required this.model,
    required this.effort,
    this.mode = ThinkingRuleMode.always,
    this.enabled = true,
  });

  /// 稳定 id，用于排序与持久化；新建时取时间戳。
  final String id;

  /// 匹配的 provider。`*` 通配。
  final String provider;

  /// 匹配的 model。`*` 通配；也支持前缀通配，如 `deepseek-*`。
  final String model;

  /// 命中后写入 `ModelSelection.reasoningEffort` 的值（efforts[i].id）。
  final String effort;

  final ThinkingRuleMode mode;
  final bool enabled;

  ThinkingRule copyWith({
    String? provider,
    String? model,
    String? effort,
    ThinkingRuleMode? mode,
    bool? enabled,
  }) => ThinkingRule(
    id: id,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    effort: effort ?? this.effort,
    mode: mode ?? this.mode,
    enabled: enabled ?? this.enabled,
  );

  /// [value] 是否匹配 [pattern]；`*` 全通配，尾部 `*` 前缀通配。
  static bool _matches(String pattern, String value) {
    if (pattern == '*' || pattern.isEmpty) return true;
    if (pattern.endsWith('*')) {
      return value.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return pattern == value;
  }

  bool matches(ModelSelection selection) =>
      _matches(provider, selection.provider) && _matches(model, selection.model);

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider,
    'model': model,
    'effort': effort,
    'mode': mode.name,
    'enabled': enabled,
  };

  static ThinkingRule? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final provider = json['provider'];
    final model = json['model'];
    final effort = json['effort'];
    if (id is! String || provider is! String || model is! String || effort is! String) return null;
    return ThinkingRule(
      id: id,
      provider: provider,
      model: model,
      effort: effort,
      mode: ThinkingRuleMode.values.asNameMap()[json['mode']] ?? ThinkingRuleMode.always,
      enabled: json['enabled'] != false,
    );
  }
}

class ThinkingRulesState {
  const ThinkingRulesState({
    this.rules = const [],
    this.fallbackEffort,
    this.loaded = false,
  });

  /// 有序规则列表，前面的优先。
  final List<ThinkingRule> rules;

  /// 没有规则命中时的兜底档位；null 表示「不改，保留当前值」。
  final String? fallbackEffort;
  final bool loaded;

  ThinkingRulesState copyWith({
    List<ThinkingRule>? rules,
    String? fallbackEffort,
    bool clearFallback = false,
    bool? loaded,
  }) => ThinkingRulesState(
    rules: rules ?? this.rules,
    fallbackEffort: clearFallback ? null : (fallbackEffort ?? this.fallbackEffort),
    loaded: loaded ?? this.loaded,
  );

  /// 首条命中生效。返回应该写进 `reasoningEffort` 的值；null = 不改。
  ///
  /// [hasManualPick] 表示用户这次是手动选过档位的：此时 `manual` 模式的规则
  /// 不覆盖用户的选择，但 `always` 模式仍然生效。
  String? evaluate(ModelSelection selection, {bool hasManualPick = false}) {
    for (final rule in rules) {
      if (!rule.enabled || !rule.matches(selection)) continue;
      if (rule.mode == ThinkingRuleMode.manual && hasManualPick) continue;
      return rule.effort;
    }
    return fallbackEffort;
  }
}

class ThinkingRulesController extends Notifier<ThinkingRulesState> {
  static const _key = 'thinking_rules_v1';

  late Future<void> _loaded;

  @override
  ThinkingRulesState build() {
    _loaded = _load();
    return const ThinkingRulesState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (!ref.mounted) return;
      if (raw == null) {
        state = const ThinkingRulesState(loaded: true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        state = const ThinkingRulesState(loaded: true);
        return;
      }
      final list = decoded['rules'];
      state = ThinkingRulesState(
        rules: list is List ? [for (final r in list) ?ThinkingRule.fromJson(r)] : const [],
        fallbackEffort: decoded['fallbackEffort'] as String?,
        loaded: true,
      );
    } catch (_) {
      // 没有偏好后端（测试）或值损坏：从空规则开始。
      if (ref.mounted) state = const ThinkingRulesState(loaded: true);
    }
  }

  Future<void> _write(ThinkingRulesState next) async {
    await _loaded;
    if (!ref.mounted) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'rules': [for (final r in next.rules) r.toJson()],
        if (next.fallbackEffort != null) 'fallbackEffort': next.fallbackEffort,
      }));
    } catch (_) {
      // 本次运行内保留。
    }
  }

  Future<void> add(ThinkingRule rule) => _write(state.copyWith(rules: [...state.rules, rule]));

  Future<void> update(String id, ThinkingRule rule) => _write(state.copyWith(
    rules: [for (final r in state.rules) r.id == id ? rule : r],
  ));

  Future<void> remove(String id) => _write(state.copyWith(
    rules: [for (final r in state.rules) r.id != id],
  ));

  /// 把 [id] 的规则与它前一条交换（上移）。
  Future<void> moveUp(String id) async {
    final i = state.rules.indexWhere((r) => r.id == id);
    if (i <= 0) return;
    final next = [...state.rules];
    final tmp = next[i - 1];
    next[i - 1] = next[i];
    next[i] = tmp;
    await _write(state.copyWith(rules: next));
  }

  /// 把 [id] 的规则与它后一条交换（下移）。
  Future<void> moveDown(String id) async {
    final i = state.rules.indexWhere((r) => r.id == id);
    if (i < 0 || i >= state.rules.length - 1) return;
    final next = [...state.rules];
    final tmp = next[i + 1];
    next[i + 1] = next[i];
    next[i] = tmp;
    await _write(state.copyWith(rules: next));
  }

  Future<void> setFallback(String? effort) => _write(state.copyWith(
    fallbackEffort: effort,
    clearFallback: effort == null,
  ));
}

final thinkingRulesProvider =
    NotifierProvider<ThinkingRulesController, ThinkingRulesState>(ThinkingRulesController.new);

/// 给 [selection] 套用规则：返回带新 effort 的 selection，没变就原样返回。
///
/// 这是规则层与现有链路的**唯一接缝**：调用方拿返回值去 `setModel()`。
ModelSelection applyThinkingRules(ModelSelection selection, ThinkingRulesState rules, {bool hasManualPick = false}) {
  final effort = rules.evaluate(selection, hasManualPick: hasManualPick);
  if (effort == null || effort == selection.reasoningEffort) return selection;
  return ModelSelection(
    provider: selection.provider,
    model: selection.model,
    reasoningEffort: effort,
  );
}