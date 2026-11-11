// 思考配置：按模型分别配置推理强度的规则列表。
//
// 页面只负责编辑规则；求值发生在发消息那一刻（chat_screen._send），
// 结果写进 ModelSelection.reasoningEffort，走 setModel() 这条已有链路。

import 'package:dsh_client/dsh_client.dart' show ModelInfo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/models_state.dart';
import '../../state/thinking_rules_state.dart';
import '../chat/model_sheet.dart' show effortLabel;
import '../common/app_sheet.dart';
import '../common/list_page_row.dart';
import '../common/segmented_pill.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

class ThinkingRulesPage extends ConsumerWidget {
  const ThinkingRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(thinkingRulesProvider);
    final controller = ref.read(thinkingRulesProvider.notifier);
    final catalog = ref.watch(currentModelCatalogProvider);

    // 档位不写死：从目录里所有模型支持的档位取并集。
    final efforts = <String>{
      for (final m in catalog?.models ?? <ModelInfo>[])
        for (final e in m.efforts) e.id,
    }.toList()
      ..sort();

    return AppPage.list(
      title: l10n.thinkingRulesTitle,
      children: [
        if (!state.loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (state.rules.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l10n.thinkingRulesEmpty, style: TextStyle(color: DshColors.of(context).textTertiary)),
            ),
          for (var i = 0; i < state.rules.length; i++)
            _RuleRow(
              rule: state.rules[i],
              first: i == 0,
              last: i == state.rules.length - 1,
              efforts: efforts,
              controller: controller,
            ),
          const SizedBox(height: 12),
          ListPageRow(
            icon: AppIcons.add,
            title: l10n.thinkingRulesAdd,
            onTap: () => _edit(context, null, efforts),
          ),
          const SizedBox(height: 20),
          _FallbackRow(efforts: efforts, controller: controller),
        ],
      ],
    );
  }

  /// 打开添加/编辑弹层。
  void _edit(BuildContext context, ThinkingRule? existing, List<String> efforts) {
    showAppSheet<void>(
      context,
      isScrollControlled: true,
      builder: (sheet) => _RuleEditor(existing: existing, efforts: efforts),
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({
    required this.rule,
    required this.first,
    required this.last,
    required this.efforts,
    required this.controller,
  });

  final ThinkingRule rule;
  final bool first;
  final bool last;
  final List<String> efforts;
  final ThinkingRulesController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: DshSurfaces.of(context).card.fill,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rule.provider} / ${rule.model}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    onChanged: (on) => controller.update(rule.id, rule.copyWith(enabled: on)),
                  ),
                ],
              ),
              Text(
                '${l10n.thinkingRulesEffort}: ${effortLabel(rule.effort)}'
                ' · ${rule.mode == ThinkingRuleMode.always ? l10n.thinkingRulesAlways : l10n.thinkingRulesManual}',
                style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: l10n.thinkingRulesMoveUp,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: first ? null : () => controller.moveUp(rule.id),
                  ),
                  IconButton(
                    tooltip: l10n.thinkingRulesMoveDown,
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: last ? null : () => controller.moveDown(rule.id),
                  ),
                  IconButton(
                    tooltip: l10n.thinkingRulesDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => controller.remove(rule.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackRow extends ConsumerWidget {
  const _FallbackRow({required this.efforts, required this.controller});

  final List<String> efforts;
  final ThinkingRulesController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(thinkingRulesProvider);
    // SegmentedPill 要求至少两段；目录还没加载时补 off/high，避免 assert。
    final available = efforts.length >= 1 ? efforts : ['off', 'high'];
    final options = <PillSegment<String?>>[
      PillSegment<String?>(null, l10n.thinkingRulesFallbackNone),
      for (final e in available) PillSegment<String?>(e, effortLabel(e)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.thinkingRulesFallback, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedPill<String?>(
            height: 40,
            segments: options,
            selected: state.fallbackEffort,
            onChanged: (v) => controller.setFallback(v),
          ),
        ],
      ),
    );
  }
}

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor({required this.existing, required this.efforts});

  final ThinkingRule? existing;
  final List<String> efforts;

  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  late final TextEditingController _provider;
  late final TextEditingController _model;
  late String _effort;
  late ThinkingRuleMode _mode;

  @override
  void initState() {
    super.initState();
    _provider = TextEditingController(text: widget.existing?.provider ?? '*');
    _model = TextEditingController(text: widget.existing?.model ?? '*');
    _effort = widget.existing?.effort ?? (widget.efforts.isEmpty ? 'high' : widget.efforts.first);
    _mode = widget.existing?.mode ?? ThinkingRuleMode.always;
  }

  @override
  void dispose() {
    _provider.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.thinkingRulesMatch, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _provider,
                decoration: InputDecoration(labelText: l10n.thinkingRulesProvider, isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _model,
                decoration: InputDecoration(labelText: l10n.thinkingRulesModel, isDense: true),
              ),
              const SizedBox(height: 16),
              Text(l10n.thinkingRulesEffort, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedPill<String>(
                height: 40,
                // SegmentedPill 要求至少两段；目录还没加载时给 off/high 两档兜底。
                segments: [
                  for (final e in widget.efforts.length >= 2 ? widget.efforts : ['off', 'high']) PillSegment(e, effortLabel(e)),
                ],
                selected: _effort,
                onChanged: (v) => setState(() => _effort = v),
              ),
              const SizedBox(height: 16),
              SegmentedPill<ThinkingRuleMode>(
                height: 40,
                segments: [
                  PillSegment(ThinkingRuleMode.always, l10n.thinkingRulesAlways),
                  PillSegment(ThinkingRuleMode.manual, l10n.thinkingRulesManual),
                ],
                selected: _mode,
                onChanged: (v) => setState(() => _mode = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final rule = ThinkingRule(
                    id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    provider: _provider.text.trim().isEmpty ? '*' : _provider.text.trim(),
                    model: _model.text.trim().isEmpty ? '*' : _model.text.trim(),
                    effort: _effort,
                    mode: _mode,
                    enabled: widget.existing?.enabled ?? true,
                  );
                  final c = ref.read(thinkingRulesProvider.notifier);
                  widget.existing == null ? c.add(rule) : c.update(rule.id, rule);
                  Navigator.of(context).pop();
                },
                child: Text(widget.existing == null ? l10n.thinkingRulesAdd : l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}