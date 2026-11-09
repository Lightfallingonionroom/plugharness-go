// 插件安装前的兼容性预检（issue #3）。
//
// 数据来源是市场索引里已有的 `MarketVersion.enginesDsh`——不需要下载插件包，
// 用户点「安装」之前就能知道这个插件要不要本机的运行时版本。
//
// 三条原则（按 issue 要求）：
//   1. 明确不满足 → 拒绝安装，并说明冲突（当前版本 / 插件声明 / 检查项）；
//   2. 没声明或写法不认识 → 允许继续，界面标「未验证兼容性」，不臆测；
//   3. 预检只读，不碰 profile / lockfile / node_modules。
import 'package:dsh_client/dsh_client.dart';

/// One check item: what was compared, what the plugin wanted, what we have.
class CompatibilityItem {
  const CompatibilityItem({
    required this.label,
    required this.declared,
    required this.actual,
    required this.verdict,
  });

  /// Human name of the check, e.g. `engines.dsh`.
  final String label;

  /// The plugin's declaration, verbatim. Null when it declared nothing.
  final String? declared;

  /// This runtime's version for the same thing.
  final String? actual;

  final RangeVerdict verdict;

  bool get blocksInstall => verdict == RangeVerdict.violates;

  bool get isUnverified => verdict == RangeVerdict.unknown;
}

/// The result of checking one plugin against this runtime.
class CompatibilityReport {
  const CompatibilityReport(this.items, {this.pluginVersion});

  final List<CompatibilityItem> items;

  /// The market version that was checked (may be null for a raw spec install).
  final String? pluginVersion;

  /// Nothing declared at all: the plugin predates the convention or does not care.
  bool get declaresNothing => items.every((i) => i.declared == null);

  /// At least one hard conflict: the install must not proceed.
  bool get blocked => items.any((i) => i.blocksInstall);

  /// Nothing blocks, but something could not be checked.
  bool get unverified => !blocked && items.any((i) => i.isUnverified);

  /// The items that would stop the install, newest problem first.
  List<CompatibilityItem> get blockers => items.where((i) => i.blocksInstall).toList(growable: false);
}

/// Check [plugin]'s market version against [runtime].
///
/// [runtime] comes from the runtime manifest (`dshVersion` / `nodeVersion`), which the
/// host reports; a null runtime means "not installed yet" and every check is `unknown`.
CompatibilityReport checkPluginCompatibility({
  required MarketPlugin plugin,
  MarketVersion? version,
  required String? dshVersion,
  required String? nodeVersion,
}) {
  final v = version ?? (plugin.versions.isEmpty ? null : plugin.versions.first);
  // A plugin with no market version is a raw-spec install; there is nothing to read.
  if (v == null) {
    return const CompatibilityReport([
      CompatibilityItem(
        label: 'engines.dsh',
        declared: null,
        actual: null,
        verdict: RangeVerdict.unknown,
      ),
    ]);
  }
  final dsh = checkVersionRange(v.enginesDsh, dshVersion);
  final items = <CompatibilityItem>[
    CompatibilityItem(
      label: 'engines.dsh',
      declared: v.enginesDsh,
      actual: dshVersion,
      verdict: dsh.verdict,
    ),
  ];
  // `engines.node` is not in the market index yet. Reading it here would mean downloading
  // the tarball, which the issue rules out for a pre-install check. Report it as unknown
  // only when we actually have a node version to show, so the panel does not invent a row.
  if (nodeVersion != null && nodeVersion.isNotEmpty) {
    items.add(CompatibilityItem(
      label: 'engines.node',
      declared: null,
      actual: nodeVersion,
      verdict: RangeVerdict.unknown,
    ));
  }
  return CompatibilityReport(items, pluginVersion: v.version);
}

/// Copy for the pre-install panel: one line per item, plus the headline.
///
/// Kept here rather than in the widget so the wording is testable and the same in the
/// market list and the install sheet.
String describeCompatibility(CompatibilityReport report, {required String locale}) {
  final zh = locale.startsWith('zh');
  if (report.blocked) {
    final first = report.blockers.first;
    final declared = first.declared ?? '?';
    final actual = first.actual ?? '?';
    return zh
        ? '这个插件要求 ${first.label} $declared，本机是 $actual，装上会加载失败。请先换个版本的插件，或升级运行时。'
        : 'This plugin needs ${first.label} $declared; this runtime is $actual and the plugin would fail to load.';
  }
  if (report.declaresNothing) {
    return zh ? '插件没有声明兼容范围，无法验证是否能在这个运行时上加载。' : 'The plugin declares no compatible range, so loading cannot be verified.';
  }
  if (report.unverified) {
    final which = report.items.where((i) => i.isUnverified).map((i) => i.label).join(', ');
    return zh ? '$which 未声明或无法验证；可以继续安装，但启动时可能加载失败。' : '$which is undeclared or unverifiable; installing is allowed but loading may fail.';
  }
  return zh ? '兼容性检查通过。' : 'Compatibility check passed.';
}
