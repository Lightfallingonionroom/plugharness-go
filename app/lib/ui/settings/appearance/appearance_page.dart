// 设置 › 主题:明暗与强调色都是 ChatGPT 式的「行 + 弹出菜单」,后面依次是
// 功能图标、桌面图标、启动图和壁纸。
//
// 明暗:一行「外观」+ 右侧当前值,点开三个选项(系统 / 浅色 / 深色)。
// 强调色:一行「强调色」+ 右侧色点与名字,点开官方十色 + 自定义。
// 其余选择器(TileStylePicker、AppIconPicker)仍共用一片网格:预览离卡片边
// 16、列间 12、名字在预览下 8。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/appearance_state.dart';
import '../../../state/settings_state.dart';
import '../../common/expand_reveal.dart';
import '../../common/pressable.dart';
import '../../shell/page_frame.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../app_menu.dart';
import '../settings_widgets.dart';
import 'app_icon_picker.dart';
import 'icon_shortcut_sheet.dart';
import 'launch_screen_section.dart';
import 'tile_style_picker.dart';
import 'wallpaper_section.dart';

/// 设置首页「外观」组的第一行:当前配色的色点 + 名字 · 明暗,点开 [AppearancePage]。
class AppearanceEntryTile extends ConsumerWidget {
  const AppearanceEntryTile({super.key, this.tint = 0});

  /// The hub group's hue.
  final int tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accent = ref.watch(accentProvider);
    final seed = accent.seedFor(Theme.of(context).brightness);
    final mode = switch (ref.watch(settingsProvider.select((s) => s.themeMode))) {
      ThemeMode.light => l10n.commonLight,
      ThemeMode.dark => l10n.commonDark,
      ThemeMode.system => l10n.commonFollowSystem,
    };
    return SettingsTile(
      icon: AppIcons.theme,
      tint: tint,
      spot: SettingsIndex.entry(SettingsPageId.appearance),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccentDot(color: seed, size: 10),
          const SizedBox(width: 6),
          Text('${accent.label} · $mode'),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AppearancePage())),
    );
  }
}

/// 设置 › 主题:明暗、配色(预设 / 自定义 / 跟随壁纸)、功能图标、桌面图标。宠物在
/// 设置首页自成一行。
///
/// 选什么都即时生效:整个 App 的主题随之交叉淡变(`AppMotion.standard`),
/// 这一页本身就是预览。
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(appearanceProvider);
    final wallpaper = ref.watch(wallpaperAccentProvider).value;
    return AppPage.list(
      title: l10n.pluginsTheme,
      children: [
        SettingsSection(
          title: l10n.hubThemeLightDark,
          children: [SpotAnchor(spot: Spots.darkMode, child: const ThemeModePicker())],
        ),
        SettingsSection(
          title: l10n.pluginsColors,
          children: [
            SpotAnchor(spot: Spots.accent, child: const PalettePicker()),
            ExpandReveal(open: appearance.source == AccentSource.custom, child: const CustomAccentPanel()),
            if (wallpaper != null) _WallpaperRow(wallpaper: wallpaper, on: appearance.source == AccentSource.wallpaper),
          ],
        ),
        SettingsSection(
          title: l10n.pluginsFeatureIcons,
          children: [SpotAnchor(spot: Spots.tileStyle, child: const TileStylePicker())],
        ),
        SettingsSection(
          title: l10n.pluginsAppIcon,
          children: [
            SpotAnchor(spot: Spots.appIcon, child: const AppIconPicker()),
            const IconShortcutTile(),
          ],
        ),
        SettingsSection(
          title: l10n.launchScreenTitle,
          footer: Text(l10n.launchFooter),
          children: [SpotAnchor(spot: Spots.launchScreen, child: const LaunchScreenSection())],
        ),
        SettingsSection(
          title: l10n.wallpaperTitle,
          footer: Text(l10n.wallpaperFooter),
          children: [SpotAnchor(spot: Spots.wallpaper, child: const WallpaperSection())],
        ),
      ],
    );
  }
}

/// The grid every picker on this page shares, with [TileStylePicker] and
/// [AppIconPicker]: content 16 from the card's edges, columns 12 apart, the
/// name 8 under its preview (or under its ring).
abstract final class PickerGrid {
  static const inset = 16.0;
  static const gap = 12.0;
  static const labelGap = 8.0;

  /// The name under a choice: the accent and heavier when chosen.
  static TextStyle labelStyle(BuildContext context, {required bool selected}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium!.copyWith(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
  }
}

// ── 外观模式 ─────────────────────────────────────────────────────────────

/// 三张小样:浅色、深色、跟随系统(左浅右深)。小样用当前配色画,换配色时
/// 跟着淡变;选中的那张外面一圈主色环。
class ThemeModePicker extends ConsumerWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    String labelOf(ThemeMode m) => switch (m) {
      ThemeMode.light => l10n.commonLight,
      ThemeMode.dark => l10n.commonDark,
      ThemeMode.system => l10n.commonFollowSystem,
    };
    // ChatGPT 的做法:一行「外观」+ 右侧当前值,点开一列三个选项。
    return AppMenuTile(
      key: const ValueKey('theme-mode-menu'),
      title: l10n.hubThemeLightDark,
      value: Text(labelOf(mode)),
      menuBuilder: (context, close) => [
        for (final m in [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
          AppMenuItem(
            label: labelOf(m),
            selected: mode == m,
            onTap: () {
              close();
              unawaited(ThemeRevealHost.run(context, () => ref.read(settingsProvider.notifier).setThemeMode(m)));
            },
          ),
      ],
    );
  }
}






// ── 配色 ─────────────────────────────────────────────────────────────────

/// 一排色点:六套预设 + 自定义(色轮)。色点画的是守卫之后、当前明暗下的
/// 主色;选中的外面一圈同色环,下面是名字。[custom] 为 false 时只有六套
/// 预设(首次启动的外观页)。
class PalettePicker extends ConsumerWidget {
  const PalettePicker({super.key, this.custom = true});

  /// The last slot, an entry to a colour of one's own.
  final bool custom;

  /// 一格色板：色点 + 名字，选中的外面一圈环。
  ///
  /// 尺寸取 4 的倍数、和设置页其它网格一致；名字在色点下面 6，最多两行
  /// （中文名都是两三个字，英文 "Magenta" 这类也放得下）。
  static const _dot = 28.0;
  static const _cellGap = 8.0;
  static const _nameGap = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final accent = ref.watch(accentProvider);
    bool chosen(AppAccent p) => appearance.source == AccentSource.preset && appearance.presetId == p.id;

    // 直接铺开：十个色板 + 自定义，排成自适应网格。
    // 这一页是"挑颜色"的地方，把色板藏在一次点击后面只会多一步；
    // ChatGPT 自己的设置页也是把色点直接摊在页面上。
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 每格至少 56 宽，放不下就换行——窄屏（320）上会自然变成 4 列。
          const minCell = 56.0;
          final columns = math.max(2, (constraints.maxWidth / (minCell + _cellGap)).floor());
          final items = [
            for (final p in AppAccent.official) (accent: p, custom: false),
            if (custom) (accent: accent, custom: true),
          ];
          return Wrap(
            spacing: _cellGap,
            runSpacing: _cellGap,
            children: [
              for (final item in items)
                SizedBox(
                  width: (constraints.maxWidth - _cellGap * (columns - 1)) / columns,
                  child: _AccentSwatch(
                    accent: item.accent,
                    label: item.custom ? l10n.pluginsCustomColor : item.accent.label,
                    color: item.custom ? accent.seedFor(brightness) : item.accent.seedFor(brightness),
                    selected: item.custom ? appearance.source == AccentSource.custom : chosen(item.accent),
                    dot: _dot,
                    nameGap: _nameGap,
                    onTap: () {
                      if (item.custom) {
                        unawaited(notifier.selectCustom());
                      } else {
                        unawaited(notifier.selectPreset(item.accent.id));
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 一格色板：色点 + 名字。选中的色点外面一圈主色环。
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.label,
    required this.color,
    required this.selected,
    required this.dot,
    required this.nameGap,
    required this.onTap,
  });

  final AppAccent accent;
  final String label;
  final Color color;
  final bool selected;
  final double dot;
  final double nameGap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: dot + 8,
                  height: dot + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? theme.colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: nameGap),
                Text(
                  label,
                  maxLines: 2,
                  minLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// What a card looks like on the page (the glass over the backdrop).

/// The hue wheel and the hue track: guarded colours every 15°, per brightness.
List<Color> _wheelColors(Brightness brightness) => _wheels[brightness] ??= [
  for (var h = 0; h <= 360; h += 15) AppAccent.guardedSeed(AppAccent.hueColor(h % 360.0), brightness),
];

final _wheels = <Brightness, List<Color>>{};


/// A small filled circle (the hub row's value, the wallpaper row).
class AccentDot extends StatelessWidget {
  const AccentDot({super.key, required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
    ),
  );
}

// ── 自定义 ───────────────────────────────────────────────────────────────

/// 自定义:色相条 + 几个推荐色。色相条和色块画的都是守卫后的颜色 —— 看到
/// 的就是用上的。
class CustomAccentPanel extends ConsumerWidget {
  const CustomAccentPanel({super.key});

  /// Picks beyond the presets: (hue, chroma, name), at the presets' lightness.
  static List<(double, double, String)> get suggestions => _suggestions(appL10n);

  static List<(double, double, String)> _suggestions(L10n l10n) => [
    (22.0, 0.10, l10n.pluginsCoral),
    (355.0, 0.10, l10n.pluginsRouge),
    (52.0, 0.075, l10n.pluginsOchre),
    (135.0, 0.075, l10n.pluginsMoss),
    (215.0, 0.09, l10n.pluginsLake),
    (282.0, 0.12, l10n.pluginsIndigo),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final choices = _suggestions(l10n);
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final pick = Color(appearance.customColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(PickerGrid.inset, 0, PickerGrid.inset, PickerGrid.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HueSlider(
            hue: Oklch.fromColor(pick).h,
            brightness: brightness,
            onChanged: (h) => unawaited(notifier.selectCustom(AppAccent.hueColor(h).toARGB32())),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (hue, chroma, name) in choices)
                Builder(
                  builder: (context) {
                    final color = AppAccent.hueColor(hue, chroma: chroma);
                    final selected = appearance.customColor == color.toARGB32();
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: name,
                      excludeSemantics: true,
                      child: Pressable(
                        onTap: () => unawaited(notifier.selectCustom(color.toARGB32())),
                        child: SizedBox.square(
                          dimension: 36,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: selected ? 1 : 0),
                            duration: AppMotion.of(context, AppMotion.quick),
                            builder: (context, t, _) => CustomPaint(
                              painter: _ChipPainter(
                                color: AppAccent.guardedSeed(color, brightness),
                                ring: t,
                                edge: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter({required this.color, required this.ring, required this.edge});

  final Color color;
  final double ring;
  final Color edge;

  static const radius = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (ring > 0) {
      canvas.drawCircle(
        c,
        radius + 2.5 + 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: ring),
      );
    }
    canvas.drawCircle(c, radius, Paint()..color = color);
    canvas.drawCircle(
      c,
      radius - 0.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.color != color || old.ring != ring || old.edge != edge;
}

/// 色相条:一条守卫后的色相渐变,一颗圆钮(里面是当前色)。拖动时圆钮
/// 跟手,主题每 ~100ms 跟一次,松手落定。
class HueSlider extends StatefulWidget {
  const HueSlider({super.key, required this.hue, required this.brightness, required this.onChanged});

  final double hue;
  final Brightness brightness;
  final ValueChanged<double> onChanged;

  static const height = 36.0;
  static const track = 12.0;
  static const knob = 26.0;

  @override
  State<HueSlider> createState() => _HueSliderState();
}

class _HueSliderState extends State<HueSlider> {
  double? _dragging;
  double _lastDx = 0;
  DateTime _sent = DateTime(0);

  double get _hue => _dragging ?? widget.hue;

  double _hueAt(double dx, double width) {
    const pad = HueSlider.knob / 2;
    return ((dx - pad) / (width - 2 * pad)).clamp(0.0, 1.0) * 360;
  }

  void _drag(double dx, double width, {bool end = false}) {
    final hue = _hueAt(dx, width);
    setState(() => _dragging = end ? null : hue);
    final now = DateTime.now();
    if (end || now.difference(_sent) > const Duration(milliseconds: 100)) {
      _sent = now;
      widget.onChanged(hue);
    }
  }

  void _step(double by) => widget.onChanged((widget.hue + by) % 360);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hue = _hue;
    final colors = _wheelColors(widget.brightness);
    final current = AppAccent.guardedSeed(AppAccent.hueColor(hue % 360), widget.brightness);
    return Semantics(
      slider: true,
      label: l10n.pluginsHue,
      value: '${hue.round()}°',
      increasedValue: '${((hue + 15) % 360).round()}°',
      decreasedValue: '${((hue - 15) % 360).round()}°',
      onIncrease: () => _step(15),
      onDecrease: () => _step(-15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _drag(d.localPosition.dx, width, end: true),
            onHorizontalDragStart: (d) => _drag(_lastDx = d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _drag(_lastDx = d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _drag(_lastDx, width, end: true),
            child: SizedBox(
              height: HueSlider.height,
              width: width,
              child: CustomPaint(
                painter: _HuePainter(
                  colors: colors,
                  hue: hue,
                  current: current,
                  knob: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.white,
                  shadow: Theme.of(context).colorScheme.shadow,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter({
    required this.colors,
    required this.hue,
    required this.current,
    required this.knob,
    required this.shadow,
  });

  final List<Color> colors;
  final double hue;
  final Color current;
  final Color knob;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = HueSlider.knob / 2;
    final track = Rect.fromLTWH(
      pad - HueSlider.track / 2,
      (size.height - HueSlider.track) / 2,
      size.width - 2 * pad + HueSlider.track,
      HueSlider.track,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(99)),
      Paint()..shader = LinearGradient(colors: colors).createShader(track),
    );
    final x = pad + (hue / 360).clamp(0.0, 1.0) * (size.width - 2 * pad);
    final c = Offset(x, size.height / 2);
    canvas.drawCircle(
      c.translate(0, 1),
      HueSlider.knob / 2,
      Paint()
        ..color = shadow.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(c, HueSlider.knob / 2, Paint()..color = knob);
    canvas.drawCircle(c, HueSlider.knob / 2 - 4, Paint()..color = current);
  }

  @override
  bool shouldRepaint(_HuePainter old) =>
      old.hue != hue || old.current != current || old.knob != knob || old.colors != colors || old.shadow != shadow;
}

// ── 跟随壁纸 ─────────────────────────────────────────────────────────────

class _WallpaperRow extends ConsumerWidget {
  const _WallpaperRow({required this.wallpaper, required this.on});

  final Color wallpaper;
  final bool on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(appearanceProvider.notifier);
    final seed = AppAccent.derive(
      wallpaper,
      id: AppAccent.wallpaperId,
      label: l10n.pluginsWallpaper,
    ).seedFor(Theme.of(context).brightness);
    void set(bool v) => unawaited(v ? notifier.selectWallpaper() : notifier.leaveWallpaper());
    return MergeSemantics(
      child: SettingsTile(
        title: l10n.pluginsFollowWallpaper,
        value: AccentDot(color: seed),
        onTap: () => set(!on),
        trailing: Switch(value: on, onChanged: set),
      ),
    );
  }
}
