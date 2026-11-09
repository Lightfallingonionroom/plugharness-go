// ChatGPT 式弹出菜单:一个设置行,点开是一列选项,选中的右侧一个 ✓。
//
// 规格来自官方 CSS(docs/CHATGPT_COMPONENTS_SPEC_2026-11-09.md):
//   容器圆角 16、内边距 6、项圆角 10、项内边距 8/12、字号 14、
//   选中/悬停底 alpha-08(浅) / alpha-10(深)、分隔线 --color-border。

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'settings_widgets.dart' show SettingsMetrics, settingsTitleStyle;

/// 菜单的度量。改这里,`test/settings/app_menu_test.dart` 一起改。
abstract final class AppMenuMetrics {
  /// 容器圆角(= 官方 `--menu-radius: var(--radius-2xl)`)。
  static const radius = 16.0;

  /// 容器内边距(= 官方 `--menu-gutter: calc(var(--spacing) * 1.5)`)。
  static const gutter = 6.0;

  /// 一项的圆角(= 容器圆角 - 内边距)。
  static const itemRadius = radius - gutter;

  /// 一项的上下 / 左右内边距。
  static const itemPadY = 8.0;
  static const itemPadX = 12.0;

  /// 图标与文字之间。
  static const itemGap = 6.0;

  /// 常见的最窄宽度:色名两个汉字加圆点加 ✓ 都放得下。
  static const minWidth = 220.0;

  /// 右侧 ✓ 的尺寸。
  static const checkSize = 16.0;
}

/// 菜单里的一项。
///
/// [leading] 画在文字左边(色点、图标);[selected] 为真时右边画 ✓。
class AppMenuItem extends StatelessWidget {
  const AppMenuItem({
    super.key,
    required this.label,
    this.leading,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leading = this.leading;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMenuMetrics.itemRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMenuMetrics.itemPadX,
              vertical: AppMenuMetrics.itemPadY,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: AppMenuMetrics.itemGap),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: AppMenuMetrics.checkSize,
                  height: AppMenuMetrics.checkSize,
                  child: selected
                      ? Icon(Icons.check, size: AppMenuMetrics.checkSize, color: scheme.primary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一条分隔线:左右各伸出 [AppMenuMetrics.gutter] 到容器边缘。
class AppMenuDivider extends StatelessWidget {
  const AppMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: -AppMenuMetrics.gutter),
    child: Divider(height: 1, thickness: 1, color: ChatGptShellColors.of(context).divider),
  );
}

/// 菜单本体:圆角 16、内边距 6、菜单底 + 发丝描边,里面一列 [AppMenuItem]。
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(AppMenuMetrics.radius),
        side: BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppMenuMetrics.minWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppMenuMetrics.gutter),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// 一个设置行 + 点开的菜单。
///
/// 行本身仍是 [SettingsTile] 的样子:图标、标题、右侧当前值和一个 ›。
/// 点一下在行下方弹出 [menuBuilder] 建的菜单。
class AppMenuTile extends StatefulWidget {
  const AppMenuTile({
    super.key,
    required this.title,
    this.icon,
    this.value,
    required this.menuBuilder,
    this.chevron = true,
  });

  final String title;
  final IconData? icon;

  /// 行右侧的当前值(色点 + 名字、模式名)。
  final Widget? value;

  /// 菜单内容;收到一个关闭菜单的回调。
  final List<Widget> Function(BuildContext context, VoidCallback close) menuBuilder;

  /// 是否画 › (菜单行都画)。
  final bool chevron;

  @override
  State<AppMenuTile> createState() => _AppMenuTileState();
}

class _AppMenuTileState extends State<AppMenuTile> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(side: BorderSide.none)),
      ),
      menuChildren: [
        AppMenuPanel(
          children: widget.menuBuilder(context, () => _controller.close()),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        splashFactory: rowSplash(context),
        highlightColor: scheme.onSurface.withValues(alpha: 0.05),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SettingsMetrics.rowHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              SettingsMetrics.inset,
              6,
              SettingsMetrics.trailingPad,
              6,
            ),
            child: Row(
              children: [
                if (widget.icon case final icon?) ...[
                  SizedBox.square(
                    dimension: SettingsMetrics.icon,
                    child: Icon(icon, size: SettingsMetrics.lineGlyph, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: SettingsMetrics.iconGap),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: settingsTitleStyle(context)?.copyWith(color: scheme.onSurface),
                  ),
                ),
                if (widget.value case final value?) ...[
                  const SizedBox(width: 12),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    child: value,
                  ),
                ],
                if (widget.chevron) ...[const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
