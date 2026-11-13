// Native Purge page: the bundled dsh-purge-go plugin's status, prompt, patches,
// rules, skills and range entry, over the engine's HTTP routes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/runtime_state.dart';
import '../../state/connection_state.dart';
import '../../state/purge_api.dart';
import '../../state/purge_state.dart';
import '../common/brief_notice.dart';
import '../features/feature_widgets.dart' show FeatureOffline;
import '../common/list_page_row.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../web/web_view_page.dart';

class PurgePage extends ConsumerStatefulWidget {
  const PurgePage({super.key});

  @override
  ConsumerState<PurgePage> createState() => _PurgePageState();
}

class _PurgePageState extends ConsumerState<PurgePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(localConnectionProvider).value;
    if (host == null) {
      return AppPage.list(title: 'Purge', children: [FeatureOffline()]);
    }
    return AppPage(
      title: 'Purge',
      subtitle: const Text('宿主兼容、补丁、破甲自检'),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: '状态'),
                  Tab(text: '提示词'),
                  Tab(text: '补丁'),
                  Tab(text: '规则'),
                  Tab(text: '技能'),
                  Tab(text: '演练台'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _PurgeStatusTab(),
                    _PurgePromptTab(),
                    _PurgePatchesTab(),
                    _PurgeRulesTab(),
                    _PurgeSkillsTab(),
                    _PurgeDrillTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
  try {
    await action();
    ref.invalidate(purgeStatusProvider);
    ref.invalidate(purgeOverrideProvider);
    ref.invalidate(purgeRulesProvider);
    ref.invalidate(purgeSkillsProvider);
    ref.invalidate(purgeDrillProvider);
    if (context.mounted) showBriefNotice(context, '完成');
  } catch (error) {
    if (context.mounted) showBriefNotice(context, '操作失败：$error');
  }
}

String _str(Map<String, dynamic> data, String key, [String fallback = '—']) =>
    data[key]?.toString() ?? fallback;

int _int(Map<String, dynamic> data, String key) => (data[key] as num?)?.toInt() ?? 0;

bool _bool(Map<String, dynamic> data, String key) => data[key] == true;

String _bytes(num? value) {
  if (value == null) return '—';
  final v = value.toDouble();
  if (v >= 1024 * 1024) return '${(v / 1024 / 1024).toStringAsFixed(1)} MB';
  if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  return '${v.toInt()} B';
}

Widget _metric(BuildContext context, String label, String value, {String? caption, Color? color}) {
  final theme = Theme.of(context);
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: color ?? theme.colorScheme.onSurface),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    ),
  );
}

Widget _kv(String label, String value) => ListPageRow(title: label, value: value);

// ── 状态 ─────────────────────────────────────────────────────────────────────

class _PurgeStatusTab extends ConsumerWidget {
  const _PurgeStatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(purgeStatusProvider);
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) => _StatusBody(data: data),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  const _StatusBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(purgeApiProvider)!;
    final patches = (data['patches'] as List? ?? const []).cast<Map<String, dynamic>>();
    final layers = <String, Map<String, int>>{};
    for (final p in patches) {
      final layer = p['layer']?.toString() ?? '其他';
      final status = p['status']?.toString() ?? 'unknown';
      layers.putIfAbsent(layer, () => {})[status] = (layers[layer]?[status] ?? 0) + 1;
    }
    final applied = _int(data, 'patches_applied');
    final total = _int(data, 'patches_total');
    final pending = _int(data, 'patches_pending');
    final backup = _bool(data, 'has_backup');
    final hooksDeny = _bool(data, 'hooks_deny_bypass');
    final operation = data['operation'] as Map<String, dynamic>?;
    final operationPhase = operation?['phase']?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListPageCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(AppIcons.systemAccess, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('清洗', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text(_str(data, 'surface'), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
           ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _metric(context, '补丁', '$applied/$total',
                        caption: pending > 0 ? '待应用 $pending' : '无待应用项',
                        color: pending > 0 ? Colors.orange : Colors.green),
                    _metric(context, 'shim', _bool(data, 'shim_cmd') ? '已注入' : '未注入',
                        caption: _bool(data, 'shim_ps1') ? 'ps1 已注入' : 'ps1 未注入'),
                    _metric(context, '备份', backup ? '在位' : '无',
                        caption: backup ? '可还原' : '先应用再备份',
                        color: backup ? Colors.green : Colors.orange),
                  ],
                ),
              ),
            ),
            _kv('宿主', _str(data, 'ai_base')),
            _kv('补丁状态', '${_int(data, 'patches_applied')}/${_int(data, 'patches_total')} · 待应用 ${_int(data, 'patches_pending')} · 跳过 ${_int(data, 'patches_skipped')} · 不适用 ${_int(data, 'patches_na')}'),
            _kv('插件版本', _str(data, 'plugin_version')),
            _kv('主文件', _str(data, 'override_path')),
            if (operationPhase != null) _kv('操作状态', operationPhase),
          ],
        ),
        const SizedBox(height: 12),
        ListPageCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('补丁分层', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final entry in layers.entries)
              ListPageRow(
                title: entry.key,
                value: entry.value.entries.map((e) => '${e.key} ${e.value}').join(' · '),
              ),
            if (layers.isEmpty) const ListPageRow(title: '暂无补丁数据', value: '—'),
          ],
        ),
        const SizedBox(height: 12),
        ListPageCard(
          children: [
            ListPageRow(
              title: 'HooksDeny 绕过',
              subtitle: '关闭后不再绕过 hooks-deny 限制',
              trailing: Switch(
                value: hooksDeny,
                onChanged: (value) => _run(context, ref, () async {
                  await api.hooksDeny(value);
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _run(context, ref, () async => api.apply()),
              icon: const Icon(AppIcons.approval),
              label: const Text('应用'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(context, ref, () async => api.revert()),
              icon: const Icon(AppIcons.refresh),
              label: const Text('还原'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(context, ref, () async => api.restart()),
              icon: const Icon(AppIcons.refresh),
              label: const Text('重启'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(context, ref, () async => api.uninstall()),
              icon: const Icon(AppIcons.delete),
              label: const Text('卸载'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(context, ref, () async => api.status()),
              icon: const Icon(AppIcons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 提示词 ───────────────────────────────────────────────────────────────────

class _PurgePromptTab extends ConsumerWidget {
  const _PurgePromptTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(purgeOverrideProvider);
    return override.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) => _PromptBody(data: data),
    );
  }
}

class _PromptBody extends ConsumerWidget {
  const _PromptBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(purgeApiProvider)!;
    final content = data['content']?.toString() ?? '';
    final defaultContent = data['defaultContent']?.toString() ?? '';
    final customized = data['customized'] == true || data['usingDefault'] == false;
    final path = data['path']?.toString() ?? '—';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListPageCard(
          children: [
            _kv('主文件', path),
            _kv('状态', customized ? '已自定义' : '默认'),
            _kv('正文长度', _bytes(content.length.toDouble())),
          ],
        ),
        const SizedBox(height: 12),
        ListPageCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('提示词正文', style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                content.isEmpty ? '（空）' : content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _run(context, ref, () async => api.override(content)),
              icon: const Icon(AppIcons.save),
              label: const Text('保存'),
            ),
            OutlinedButton.icon(
              onPressed: defaultContent.isEmpty
                  ? null
                  : () => _run(context, ref, () async => api.override(defaultContent)),
              icon: const Icon(AppIcons.refresh),
              label: const Text('恢复默认'),
            ),
            OutlinedButton.icon(
              onPressed: content.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: content));
                      showBriefNotice(context, '已复制');
                    },
              icon: const Icon(AppIcons.copy),
              label: const Text('复制'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 补丁 ─────────────────────────────────────────────────────────────────────

class _PurgePatchesTab extends ConsumerWidget {
  const _PurgePatchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(purgeStatusProvider);
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) {
        final patches = (data['patches'] as List? ?? const []).cast<Map<String, dynamic>>();
        final layers = <String, List<Map<String, dynamic>>>{};
        for (final p in patches) {
          final layer = p['layer']?.toString() ?? '其他';
          layers.putIfAbsent(layer, () => []).add(p);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            for (final entry in layers.entries) ...[
              ListPageCard(
                title: entry.key,
                children: [
                  for (final p in entry.value)
                    ListPageRow(
                      title: p['id']?.toString() ?? '—',
                      subtitle: (p['ids'] as List? ?? const []).join(', '),
                      value: p['status']?.toString() ?? '—',
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (layers.isEmpty)
              const ListPageCard(children: [ListPageRow(title: '暂无补丁数据', value: '—')]),
          ],
        );
      },
    );
  }
}

// ── 规则 ─────────────────────────────────────────────────────────────────────

class _PurgeRulesTab extends ConsumerWidget {
  const _PurgeRulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(purgeRulesProvider);
    return rules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) => _RulesBody(data: data),
    );
  }
}

class _RulesBody extends ConsumerWidget {
  const _RulesBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(purgeApiProvider)!;
    final rules = (data['rules'] as List? ?? const []).cast<Map<String, dynamic>>();
    final candidates = (data['candidates'] as List? ?? const []).cast<Map<String, dynamic>>();
    final selections = (data['selections'] as List? ?? const []).cast<String>();
    final policy = data['policy']?.toString() ?? 'fallback';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListPageCard(
          children: [
            ListPageRow(
              title: '工作区策略',
              value: policy,
              trailing: DropdownButton<String>(
                value: policy,
                items: const [
                  DropdownMenuItem(value: 'fallback', child: Text('fallback')),
                  DropdownMenuItem(value: 'strict', child: Text('strict')),
                  DropdownMenuItem(value: 'always', child: Text('always')),
                ],
                onChanged: (value) => _run(context, ref, () async {
                  if (value != null) await api.rules('set-policy', {'policy': value});
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListPageCard(
          title: '规则',
          children: [
            for (final rule in rules)
              ListPageRow(
                title: rule['name']?.toString() ?? rule['id']?.toString() ?? '—',
                subtitle: '${rule['target'] ?? '—'} · ${_bytes((rule['size'] as num?)?.toDouble() ?? 0)}',
                value: (rule['enabled'] == true || rule['active'] == true) ? '使用中' : '',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _run(context, ref, () async {
                        await api.rules('activate', {'id': rule['id']});
                      }),
                      child: const Text('使用'),
                    ),
                    TextButton(
                      onPressed: () => _run(context, ref, () async {
                        await api.rules('delete', {'id': rule['id']});
                      }),
                      child: const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            if (rules.isEmpty) const ListPageRow(title: '暂无规则', value: '—'),
          ],
        ),
        const SizedBox(height: 12),
        ListPageCard(
          title: '工作区候选',
          children: [
            for (final candidate in candidates)
              ListPageRow(
                title: candidate['name']?.toString() ?? candidate['path']?.toString() ?? '—',
                subtitle: candidate['path']?.toString() ?? '',
                trailing: Checkbox(
                  value: selections.contains(candidate['path']),
                  onChanged: (value) => _run(context, ref, () async {
                    await api.rules('toggle-cwd', {
                      'path': candidate['path'],
                      'enabled': value ?? false,
                    });
                  }),
                ),
              ),
            if (candidates.isEmpty) const ListPageRow(title: '暂无候选', value: '—'),
          ],
        ),
      ],
    );
  }
}

// ── 技能 ─────────────────────────────────────────────────────────────────────

class _PurgeSkillsTab extends ConsumerWidget {
  const _PurgeSkillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(purgeSkillsProvider);
    return skills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) => _SkillsBody(data: data),
    );
  }
}

class _SkillsBody extends ConsumerWidget {
  const _SkillsBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(purgeApiProvider)!;
    final skills = (data['skills'] as List? ?? const []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListPageCard(
          title: '技能',
          children: [
            for (final skill in skills)
              ListPageRow(
                title: skill['id']?.toString() ?? '—',
                subtitle: skill['description']?.toString() ?? '',
                value: _bytes((skill['size'] as num?)?.toDouble() ?? 0),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _run(context, ref, () async {
                        final detail = await api.skills('read', {'id': skill['id']});
                        if (!context.mounted) return;
                        final content = await _editText(
                          context,
                          skill['id']?.toString() ?? '',
                          detail['content']?.toString() ?? '',
                        );
                        if (content != null) {
                          await api.skills('save', {'id': skill['id'], 'content': content});
                        }
                      }),
                      child: const Text('编辑'),
                    ),
                    TextButton(
                      onPressed: () => _run(context, ref, () async {
                        await api.skills('delete', {'id': skill['id']});
                      }),
                      child: const Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            if (skills.isEmpty) const ListPageRow(title: '暂无技能', value: '—'),
          ],
        ),
      ],
    );
  }
}

Future<String?> _editText(BuildContext context, String title, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 12,
        minLines: 6,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('保存')),
      ],
    ),
  );
}

// ── 演练台 ───────────────────────────────────────────────────────────────────

class _PurgeDrillTab extends ConsumerWidget {
  const _PurgeDrillTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drill = ref.watch(purgeDrillProvider);
    final runtime = ref.watch(localRuntimeProvider.select((s) => s.status));
    return drill.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('读取失败：$error', textAlign: TextAlign.center),
      )),
      data: (data) {
        final granted = data['granted'] == true;
        final api = ref.read(purgeApiProvider)!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ListPageCard(
              children: [
                _kv('授权状态', granted ? '已授权' : '未授权'),
                if (data['at'] != null) _kv('授权时间', data['at'].toString()),
                if (data['path'] != null) _kv('授权文件', data['path'].toString()),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: granted ? null : () => _run(context, ref, () async => api.grantDrill()),
                  icon: const Icon(AppIcons.systemAccess),
                  label: const Text('授权演练台'),
                ),
                OutlinedButton.icon(
                  onPressed: runtime.baseUrl == null
                      ? null
                      : () {
                          final url = Uri.parse(runtime.baseUrl!).replace(
                            path: '/dsh-purge/',
                            queryParameters: {'token': runtime.token},
                          );
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => WebViewPage(
                              url: url,
                              title: '演练台',
                              dshWeb: false,
                            ),
                          ));
                        },
                  icon: const Icon(AppIcons.openExternal),
                  label: const Text('打开网页版演练台'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
