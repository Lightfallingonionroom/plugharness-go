// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'accent.dart';
import 'oklch.dart';
import 'surfaces.dart';

/// ChatGPT 式中性配色:**手工构造**,不走 `ColorScheme.fromSeed`。
///
/// 为什么不用 fromSeed:M3 tonalSpot 会把任何种子推成一套高彩度"现代 App"
/// 色阶,恰好抹掉这里要的低饱和。所以每个槽位手工指定。
///
/// ## 两套印次
///
/// - 浅色:纸白。页面是纯色 `#FFFFFF`(官方 `--color-surface` = gray-0),
///   卡片面 `#F9F9F9` / 输入面 `#F3F3F3`。
/// - 深色:中性炭灰 `#212121`(官方 `--gray-200` = surface),比侧栏
///   `#171717` 浅一档、比卡片 `#303030` 深一档。**无蓝调**——这是
///   "层级靠明度递进,不靠染色"的官方做法。
/// - 数值全部来自 openai/apps-sdk-ui 源码实测,见
///   `docs/openai-sdk-ui-spec.md` §3 的 `--gray-*` 表;改之前先读它。
///
/// ## 比例
///
/// 70% 中性面(渐变 + 玻璃)、25% 文字与细线、≤5% 强调色。强调色只出现在
/// 主按钮、发送键、选中态、链接、进度。铺多了就不"静"了。
///
/// ## 配色
///
/// 这里的中性色常量是**默认(石墨)配色**的。用户换成别的配色,页面、玻璃、
/// 文字走 [NeutralTones](同明度、换色调),界面代码一律从主题取色,不直接用
/// 这些常量;暮紫 tertiary 和错误色是语义色,不随配色转。
abstract final class DshPalette {
  // ══ 浅色:纸白(官方 gray-0 / gray-50 / gray-75)═════════
  /// 页面渐变顶 · 纯白(官方 `--color-surface` = gray-0)。
  static const mistTop = Color(0xFFFFFFFF);

  /// 页面渐变底 · 与顶同色 —— 官方页面是纯色,不是渐变。
  static const mistBottom = Color(0xFFFFFFFF);

  /// 不透明页面底(渐变的中值;无法铺渐变时用)。
  static const mist = Color(0xFFFFFFFF);

  /// 面色阶梯(不透明),玻璃关闭或 M3 组件需要实色时用。
  /// 官方:gray-0 → gray-50 → gray-75 → gray-100 → gray-150。
  static const mistLowest = Color(0xFFFFFFFF);
  static const mistLow = Color(0xFFF9F9F9);
  static const mistContainer = Color(0xFFF3F3F3);
  static const mistHigh = Color(0xFFECECEC);
  static const mistHighest = Color(0xFFE5E5E5);

  /// 主文字 · 近黑(官方 `--color-text` = gray-1000)。
  static const ink = Color(0xFF0D0D0D);

  /// 次级文字(官方 `--color-text-secondary` = gray-500)。
  static const inkMuted = Color(0xFF5D5D5D);

  /// 三级文字 · 时间戳、摘要、占位符(官方 `--color-text-tertiary` = gray-400)。
  static const inkFaint = Color(0xFF8F8F8F);

  /// 禁用 / 纯装饰(约 2.5,**不得**承载必要信息)。
  static const inkGhost = Color(0xFFAFAFAF);

  /// 输入框等交互边界(非文字对比 ≥ 3)。
  static const outlineLight = Color(0xFF8F8F8F);

  /// 分割线 / 发丝描边(装饰性)。
  static const ruleLight = Color(0xFFE5E5E5);

  /// 冷墨阴影基色:阴影带一点蓝,比纯黑阴影干净。
  static const shadowInk = Color(0xFF0B152D);

  // ══ 深色:中性炭灰(官方 gray-200 系)══════════════════
  static const nightTop = Color(0xFF212121);
  static const nightBottom = Color(0xFF212121);
  static const night = Color(0xFF212121);
  static const nightLowest = Color(0xFF171717);
  static const nightLow = Color(0xFF282828);
  static const nightContainer = Color(0xFF303030);
  static const nightHigh = Color(0xFF303030);
  static const nightHighest = Color(0xFF393939);

  /// 主文字 · 官方 `--gray-900`。
  static const paper = Color(0xFFECECEC);
  static const paperMuted = Color(0xFFAFAFAF);
  static const paperFaint = Color(0xFF8F8F8F);
  static const paperGhost = Color(0xFF5D5D5D);
  static const outlineDark = Color(0xFF414141);
  static const ruleDark = Color(0xFF2F2F2F);
  static const shadowNight = Color(0xFF000000);

  // ══ 中性辅助色(两套共用的语义角色) ═════════════════════
  /// 浅色 secondary · 板岩蓝灰:次要按钮、未选中强调。
  static const slate = Color(0xFF545E6F);
  static const slateContainer = Color(0xFFE2E6F0);

  /// 深色 secondary。tonal 按钮底是叠在玻璃卡上约 9% 的白,和卡片拉开层次。
  static const slateLift = Color(0xFFB3BED2);
  static const onSlateLift = Color(0xFF1A2230);
  static const slateContainerDark = Color(0x17FFFFFF);

  /// tertiary · 暮紫:计划 / 目标 / 子代理这类"智能体在规划"的点缀。
  static const dusk = Color(0xFF6B578F);
  static const duskContainer = Color(0xFFECE5FB);
  static const onDuskContainer = Color(0xFF3B2C54);
  static const duskLift = Color(0xFFBEAEDE);
  static const onDuskLift = Color(0xFF251C36);
  static const duskContainerDark = Color(0xFF3E3451);
  static const onDuskContainerDark = Color(0xFFE4DDF3);

  // ══ 错误(低饱和砖玫红,与 DshColors 的 danger 同值) ═══
  static const danger = Color(0xFFA54743);
  static const onDanger = Color(0xFFFDF9F8);
  static const dangerContainer = Color(0xFFFFE2E0);
  static const onDangerContainer = Color(0xFF642724);
  static const dangerLift = Color(0xFFE69089);
  static const onDangerLift = Color(0xFF331513);
  static const dangerContainerDark = Color(0xFF542C29);
  static const onDangerContainerDark = Color(0xFFF8D9D7);

  /// 遮罩基色(抽屉、模态底)。
  static const scrim = Color(0xFF0B111F);

  /// 浅色方案。
  ///
  /// `surface` 是不透明兜底;真正的页面背景由 `AppBackdrop` 画渐变,
  /// 卡片 / 顶栏 / 输入条走 `GlassSurface`。`surfaceContainer*` 五档仍按
  /// "越高越深"排,给没有玻璃的 M3 组件(菜单、对话框、Chip)用。
  static ColorScheme lightScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.light,
      primary: accent.seed,
      onPrimary: accent.onSeed,
      primaryContainer: accent.container,
      onPrimaryContainer: accent.onContainer,
      secondary: n.slate,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: n.slateContainer,
      onSecondaryContainer: n.ink,
      // 暮紫是"智能体在规划"的语义色,不随配色转。
      tertiary: dusk,
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: duskContainer,
      onTertiaryContainer: onDuskContainer,
      error: danger,
      onError: onDanger,
      errorContainer: dangerContainer,
      onErrorContainer: onDangerContainer,
      surface: n.mist,
      onSurface: n.ink,
      onSurfaceVariant: n.inkMuted,
      surfaceDim: n.mistHighest,
      surfaceBright: n.mistLowest,
      surfaceContainerLowest: n.mistLowest,
      surfaceContainerLow: n.mistLow,
      surfaceContainer: n.mistContainer,
      surfaceContainerHigh: n.mistHigh,
      surfaceContainerHighest: n.mistHighest,
      // 关掉 M3 的 elevation 着色:层次靠玻璃和细线,不靠给面染主色。
      surfaceTint: Colors.transparent,
      inverseSurface: n.inverseSurface,
      onInverseSurface: n.onInverseSurface,
      inversePrimary: accent.seedDark,
      outline: n.outlineLight,
      outlineVariant: n.ruleLight,
      shadow: n.shadowInk,
      scrim: n.scrim,
    );
  }

  /// 深色方案:深海石板 + 提亮主色(深墨字)。
  static ColorScheme darkScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: accent.seedDark,
      onPrimary: accent.onSeedDark,
      primaryContainer: accent.containerDark,
      onPrimaryContainer: accent.onContainerDark,
      secondary: n.slateLift,
      onSecondary: n.onSlateLift,
      secondaryContainer: slateContainerDark,
      onSecondaryContainer: n.paper,
      tertiary: duskLift,
      onTertiary: onDuskLift,
      tertiaryContainer: duskContainerDark,
      onTertiaryContainer: onDuskContainerDark,
      error: dangerLift,
      onError: onDangerLift,
      errorContainer: dangerContainerDark,
      onErrorContainer: onDangerContainerDark,
      surface: n.night,
      onSurface: n.paper,
      onSurfaceVariant: n.paperMuted,
      surfaceDim: n.nightLowest,
      surfaceBright: n.nightHighest,
      surfaceContainerLowest: n.nightLowest,
      surfaceContainerLow: n.nightLow,
      surfaceContainer: n.nightContainer,
      surfaceContainerHigh: n.nightHigh,
      surfaceContainerHighest: n.nightHighest,
      surfaceTint: Colors.transparent,
      inverseSurface: n.paper,
      onInverseSurface: n.ink,
      inversePrimary: accent.seed,
      outline: n.outlineDark,
      outlineVariant: n.ruleDark,
      shadow: n.shadowNight,
      scrim: const Color(0xFF000000),
    );
  }
}

/// 一套配色下的全部中性色:页面渐变、面色阶梯、各级文字、细线、阴影、
/// 代码井、终端。
///
/// [defaults] 就是 [DshPalette] 里那些常量;别的配色由 [of] 把它整条转到
/// `AppAccent.tintHue` 上,彩度乘 `AppAccent.tintChroma`,**明度一点不动**
/// —— 所以文字对比度、玻璃层次在每套配色里都一样(测试逐条验)。
@immutable
class NeutralTones {
  const NeutralTones({
    required this.mistTop,
    required this.mistBottom,
    required this.mist,
    required this.mistLowest,
    required this.mistLow,
    required this.mistContainer,
    required this.mistHigh,
    required this.mistHighest,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.outlineLight,
    required this.ruleLight,
    required this.shadowInk,
    required this.slate,
    required this.slateContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.scrim,
    required this.codeWell,
    required this.codeWellHeader,
    required this.codeWellBorder,
    required this.lineNumber,
    required this.comment,
    required this.nightTop,
    required this.nightBottom,
    required this.night,
    required this.nightLowest,
    required this.nightLow,
    required this.nightContainer,
    required this.nightHigh,
    required this.nightHighest,
    required this.paper,
    required this.paperMuted,
    required this.paperFaint,
    required this.paperGhost,
    required this.outlineDark,
    required this.ruleDark,
    required this.shadowNight,
    required this.slateLift,
    required this.onSlateLift,
    required this.smoke,
    required this.sheetDark,
    required this.codeWellDark,
    required this.codeWellHeaderDark,
    required this.codeWellBorderDark,
    required this.lineNumberDark,
    required this.commentDark,
    required this.terminal,
    required this.terminalKey,
  });

  final Color mistTop, mistBottom, mist, mistLowest, mistLow, mistContainer, mistHigh, mistHighest;
  final Color ink, inkMuted, inkFaint, inkGhost, outlineLight, ruleLight, shadowInk;
  final Color slate, slateContainer, inverseSurface, onInverseSurface, scrim;

  /// 浅色代码井:底、标题条、描边、行号;代码注释。
  final Color codeWell, codeWellHeader, codeWellBorder, lineNumber, comment;

  final Color nightTop, nightBottom, night, nightLowest, nightLow, nightContainer, nightHigh, nightHighest;
  final Color paper, paperMuted, paperFaint, paperGhost, outlineDark, ruleDark, shadowNight;
  final Color slateLift, onSlateLift;

  /// 深色玻璃:chrome 的烟灰、弹层的底。
  final Color smoke, sheetDark;

  final Color codeWellDark, codeWellHeaderDark, codeWellBorderDark, lineNumberDark, commentDark;

  /// 终端卡(浅色模式也是深底)和它的按键底。
  final Color terminal, terminalKey;

  /// 雾蓝中性色所在的色相。
  static const baseHue = 266.0;

  /// 雾蓝的中性色(就是 [DshPalette] 的常量)。
  static const defaults = NeutralTones(
    mistTop: DshPalette.mistTop,
    mistBottom: DshPalette.mistBottom,
    mist: DshPalette.mist,
    mistLowest: DshPalette.mistLowest,
    mistLow: DshPalette.mistLow,
    mistContainer: DshPalette.mistContainer,
    mistHigh: DshPalette.mistHigh,
    mistHighest: DshPalette.mistHighest,
    ink: DshPalette.ink,
    inkMuted: DshPalette.inkMuted,
    inkFaint: DshPalette.inkFaint,
    inkGhost: DshPalette.inkGhost,
    outlineLight: DshPalette.outlineLight,
    ruleLight: DshPalette.ruleLight,
    shadowInk: DshPalette.shadowInk,
    slate: DshPalette.slate,
    slateContainer: DshPalette.slateContainer,
    inverseSurface: Color(0xFFECECEC),
    onInverseSurface: Color(0xFF212121),
    scrim: DshPalette.scrim,
    codeWell: Color(0xFFF3F3F3),
    codeWellHeader: Color(0xFFECECEC),
    codeWellBorder: Color(0xFFE5E5E5),
    lineNumber: Color(0xFF8F8F8F),
    comment: Color(0xFF5D5D5D),
    nightTop: DshPalette.nightTop,
    nightBottom: DshPalette.nightBottom,
    night: DshPalette.night,
    nightLowest: DshPalette.nightLowest,
    nightLow: DshPalette.nightLow,
    nightContainer: DshPalette.nightContainer,
    nightHigh: DshPalette.nightHigh,
    nightHighest: DshPalette.nightHighest,
    paper: DshPalette.paper,
    paperMuted: DshPalette.paperMuted,
    paperFaint: DshPalette.paperFaint,
    paperGhost: DshPalette.paperGhost,
    outlineDark: DshPalette.outlineDark,
    ruleDark: DshPalette.ruleDark,
    shadowNight: DshPalette.shadowNight,
    slateLift: DshPalette.slateLift,
    onSlateLift: DshPalette.onSlateLift,
    smoke: Color(0xFF2F2F2F),
    sheetDark: Color(0xFF303030),
    codeWellDark: Color(0xFF181818),
    codeWellHeaderDark: Color(0xFF212121),
    codeWellBorderDark: Color(0xFF2F2F2F),
    lineNumberDark: Color(0xFF777777),
    commentDark: Color(0xFF8F8F8F),
    terminal: Color(0xFF12151C),
    terminalKey: Color(0xFF262A33),
  );

  static final _cache = <(double, double), NeutralTones>{};

  static NeutralTones forAccent(AppAccent accent) => of(tintHue: accent.tintHue, tintChroma: accent.tintChroma);

  /// 当前主题那套配色的中性色。
  static NeutralTones current(BuildContext context) =>
      forAccent(Theme.of(context).extension<DshSurfaces>()?.accent ?? AppAccent.graphite);

  /// 把一个按雾蓝调出来的中性色换到 [accent] 的色调上(零散的灰,比如图表
  /// 里的「其他」)。
  static Color tint(Color mistNeutral, AppAccent accent) => retint(
    mistNeutral,
    hueShift: accent.tintHue - baseHue,
    chromaScale: accent.tintChroma,
    absoluteHue: accent.tintHue,
  );

  /// 转到 [tintHue]、彩度乘 [tintChroma] 的整条中性色。结果按参数缓存。
  static NeutralTones of({required double tintHue, required double tintChroma}) {
    if (tintHue == baseHue && tintChroma == 1) return defaults;
    return _cache.putIfAbsent((tintHue, tintChroma), () {
      if (_cache.length > 32) _cache.clear();
      final shift = tintHue - baseHue;
      // The whole ramp is grey, so every entry lands on [tintHue] itself. Passing
      // it as the absolute hue is what keeps 蓝色 blue: rotating a grey's
      // meaningless 0° hue would put it wherever atan2(0,0) happens to sit.
      Color t(Color c) => retint(c, hueShift: shift, chromaScale: tintChroma, absoluteHue: tintHue);
      const m = defaults;
      return NeutralTones(
        mistTop: t(m.mistTop),
        mistBottom: t(m.mistBottom),
        mist: t(m.mist),
        mistLowest: t(m.mistLowest),
        mistLow: t(m.mistLow),
        mistContainer: t(m.mistContainer),
        mistHigh: t(m.mistHigh),
        mistHighest: t(m.mistHighest),
        ink: t(m.ink),
        inkMuted: t(m.inkMuted),
        inkFaint: t(m.inkFaint),
        inkGhost: t(m.inkGhost),
        outlineLight: t(m.outlineLight),
        ruleLight: t(m.ruleLight),
        shadowInk: t(m.shadowInk),
        slate: t(m.slate),
        slateContainer: t(m.slateContainer),
        inverseSurface: t(m.inverseSurface),
        onInverseSurface: t(m.onInverseSurface),
        scrim: t(m.scrim),
        codeWell: t(m.codeWell),
        codeWellHeader: t(m.codeWellHeader),
        codeWellBorder: t(m.codeWellBorder),
        lineNumber: t(m.lineNumber),
        comment: t(m.comment),
        nightTop: t(m.nightTop),
        nightBottom: t(m.nightBottom),
        night: t(m.night),
        nightLowest: t(m.nightLowest),
        nightLow: t(m.nightLow),
        nightContainer: t(m.nightContainer),
        nightHigh: t(m.nightHigh),
        nightHighest: t(m.nightHighest),
        paper: t(m.paper),
        paperMuted: t(m.paperMuted),
        paperFaint: t(m.paperFaint),
        paperGhost: t(m.paperGhost),
        outlineDark: t(m.outlineDark),
        ruleDark: t(m.ruleDark),
        shadowNight: t(m.shadowNight),
        slateLift: t(m.slateLift),
        onSlateLift: t(m.onSlateLift),
        smoke: t(m.smoke),
        sheetDark: t(m.sheetDark),
        codeWellDark: t(m.codeWellDark),
        codeWellHeaderDark: t(m.codeWellHeaderDark),
        codeWellBorderDark: t(m.codeWellBorderDark),
        lineNumberDark: t(m.lineNumberDark),
        commentDark: t(m.commentDark),
        terminal: t(m.terminal),
        terminalKey: t(m.terminalKey),
      );
    });
  }
}

/// WCAG 2.x 相对亮度对比度。给测试和运行时断言用。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
