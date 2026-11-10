// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'oklch.dart';
import 'palette.dart';

/// 一套配色:强调色的浅深两套色阶,加上中性色(页面、玻璃、文字)往哪个
/// 色调上染。枚举不了的(自定义、跟随壁纸)由 [AppAccent.derive] 现推。
///
/// ## 推导规则(OKLCH,所有色相同一把尺子)
///
/// DeepSeek 品牌蓝 `#4D6BFE` 是 OKLCH(0.59, 0.22, 270):饱和度几乎顶格,
/// 大面积看久了刺眼。默认 [mist] 保留它的色相(267°),彩度压到 0.125,
/// 明度 0.53,白字 5.39。其余每套只换色相和彩度,明度照抄:
///
/// | 角色 | 明度 L | 彩度(× 强调彩度) |
/// |---|---|---|
/// | seed / pressed | 0.53 / 0.47 | 1 / 0.95 |
/// | container / onContainer | 0.93 / 0.33 | 0.26 / 0.70 |
/// | bubble / glow | 0.918 / 0.819 | 0.29 / 0.68 |
/// | seedDark / pressedDark | 0.764 / 0.704 | 0.76 |
/// | onSeedDark | 0.231 | 0.39 |
/// | containerDark / onContainerDark | 0.361 / 0.909 | 0.51 / 0.24 |
/// | bubbleDark / glowDark | 0.314 / 0.52 | 0.29 / 0.72 |
///
/// - 浅色主色上用白字(≥ 4.5),深色主色上用同色相的深墨字(≥ 7)。
/// - 中性色:雾蓝那条中性色阶原样转到 [tintHue],彩度乘 [tintChroma]
///   (见 `NeutralTones`)。明度不动,所以各级文字的对比度不随配色变。
/// - [haze]:页面左下角那团光,配主色的邻近色,给玻璃一点可透的颜色。
///
/// 每套预设都在 `test/theme/palette_contrast_test.dart` 里逐条验对比度。
@immutable
class AppAccent {
  const AppAccent({
    required this.id,
    this._label,
    required this.seed,
    required this.pressed,
    required this.container,
    required this.onContainer,
    required this.bubble,
    required this.glow,
    required this.seedDark,
    required this.pressedDark,
    required this.onSeedDark,
    required this.containerDark,
    required this.onContainerDark,
    required this.bubbleDark,
    required this.glowDark,
    required this.tintHue,
    required this.tintChroma,
    required this.haze,
    required this.hazeDark,
  });

  /// 持久化键:预设名,或 [customId] / [wallpaperId]。
  final String id;

  /// 设置页展示名。
  final String? _label;

  String get label =>
      _label ??
      switch (id) {
        'mist' => appL10n.phoneAccentMist,
        'daiqing' => appL10n.phoneAccentDaiqing,
        'dusk' => appL10n.phoneAccentDusk,
        'turquoise' => appL10n.phoneAccentTurquoise,
        'amber' => appL10n.phoneAccentAmber,
        'graphite' => appL10n.phoneAccentGraphite,
        'official_blue' => appL10n.phoneAccentBlue,
        'official_cyan' => appL10n.phoneAccentCyan,
        'official_green' => appL10n.phoneAccentGreen,
        'official_lime' => appL10n.phoneAccentLime,
        'official_yellow' => appL10n.phoneAccentYellow,
        'official_orange' => appL10n.phoneAccentOrange,
        'official_pink' => appL10n.phoneAccentPink,
        'official_magenta' => appL10n.phoneAccentMagenta,
        'official_purple' => appL10n.phoneAccentPurple,
        _ => appL10n.phoneAccentCustom,
      };

  /// 浅色主色(色板上显示的颜色)。白字 ≥ 4.5。
  final Color seed;

  /// 浅色按下态。
  final Color pressed;

  /// 浅色:强调容器 / 其上前景(≥ 7)。
  final Color container;
  final Color onContainer;

  /// 浅色用户气泡:比页面深一档(OKLCH L 0.918),像轻轻按进纸里的一块。
  /// 气泡里只用主文字 / 次级文字(≥ 5.8),三级文字和主色在这里不过 AA。
  final Color bubble;

  /// 浅色背景光晕(使用时再乘透明度)。
  final Color glow;

  /// 深色主色:提亮版,配 [onSeedDark] 深墨字。
  final Color seedDark;
  final Color pressedDark;
  final Color onSeedDark;
  final Color containerDark;
  final Color onContainerDark;
  final Color bubbleDark;
  final Color glowDark;

  /// 中性色转到的色相(度)。雾蓝的中性色在 [NeutralTones.baseHue]。
  final double tintHue;

  /// 中性色的彩度倍数(雾蓝 = 1;石墨接近 0)。
  final double tintChroma;

  /// 左下角光晕(浅 / 深;使用时再乘透明度)。
  final Color haze;
  final Color hazeDark;

  /// 浅色主色上的文字。所有配色都是白字。
  Color get onSeed => const Color(0xFFFFFFFF);

  /// 按亮度取主色。
  Color seedFor(Brightness brightness) => brightness == Brightness.dark ? seedDark : seed;

  // ══ 预设 ══════════════════════════════════════════════════════════════

  /// 默认:雾蓝。DeepSeek 色相,低彩度。
  static const mist = AppAccent(
    id: 'mist',
    seed: Color(0xFF4B67B4),
    pressed: Color(0xFF3D569D),
    container: Color(0xFFDEE8FF),
    onContainer: Color(0xFF213262),
    bubble: Color(0xFFD9E4FD),
    glow: Color(0xFFABC3FC),
    seedDark: Color(0xFF97B1F0),
    pressedDark: Color(0xFF859EDC),
    onSeedDark: Color(0xFF121C34),
    containerDark: Color(0xFF2E3C5F),
    onContainerDark: Color(0xFFD8E1F6),
    bubbleDark: Color(0xFF293144),
    glowDark: Color(0xFF51679D),
    tintHue: NeutralTones.baseHue,
    tintChroma: 1,
    haze: Color(0xFFD5CBEB),
    hazeDark: Color(0xFF514765),
  );

  /// 黛青:墨蓝偏青(238°),比雾蓝沉一档(L 0.47),彩度收到 0.085。
  /// 中性色带一点湖青,光晕配长春花蓝。
  static const daiqing = AppAccent(
    id: 'daiqing',
    seed: Color(0xFF236185),
    pressed: Color(0xFF145071),
    container: Color(0xFFDBEAF5),
    onContainer: Color(0xFF123950),
    bubble: Color(0xFFD6E7F3),
    glow: Color(0xFFA2CAE5),
    seedDark: Color(0xFF8CB9D7),
    pressedDark: Color(0xFF79A6C4),
    onSeedDark: Color(0xFF0D1F2B),
    containerDark: Color(0xFF274152),
    onContainerDark: Color(0xFFD5E3ED),
    bubbleDark: Color(0xFF26333C),
    glowDark: Color(0xFF466E88),
    tintHue: 238,
    tintChroma: 0.9,
    haze: Color(0xFFC7D0EC),
    hazeDark: Color(0xFF444C66),
  );

  /// 暮紫:灰调薰衣草(300°,彩度 0.075)。光晕配一点灰玫瑰。
  static const dusk = AppAccent(
    id: 'dusk',
    seed: Color(0xFF726291),
    pressed: Color(0xFF61517D),
    container: Color(0xFFEAE5F4),
    onContainer: Color(0xFF392F4C),
    bubble: Color(0xFFE6E1F1),
    glow: Color(0xFFC8BDE1),
    seedDark: Color(0xFFB8ABD2),
    pressedDark: Color(0xFFA598BF),
    onSeedDark: Color(0xFF1F1A29),
    containerDark: Color(0xFF40394F),
    onContainerDark: Color(0xFFE2DEEC),
    bubbleDark: Color(0xFF332F3B),
    glowDark: Color(0xFF6D6284),
    tintHue: 295,
    tintChroma: 0.85,
    haze: Color(0xFFE6C7D7),
    hazeDark: Color(0xFF5F4353),
  );

  /// 松石:低饱和青绿(186°,彩度 0.068)。中性色只带三成青,免得发绿发灰;
  /// 光晕配天青。
  static const turquoise = AppAccent(
    id: 'turquoise',
    seed: Color(0xFF34766F),
    pressed: Color(0xFF296760),
    container: Color(0xFFDBECE9),
    onContainer: Color(0xFF123D39),
    bubble: Color(0xFFD6E8E6),
    glow: Color(0xFFA3CEC8),
    seedDark: Color(0xFF8DBEB7),
    pressedDark: Color(0xFF7BABA4),
    onSeedDark: Color(0xFF0D211F),
    containerDark: Color(0xFF274340),
    onContainerDark: Color(0xFFD6E5E2),
    bubbleDark: Color(0xFF263533),
    glowDark: Color(0xFF47726D),
    tintHue: 190,
    tintChroma: 0.7,
    haze: Color(0xFFB9D7E3),
    hazeDark: Color(0xFF34525E),
  );

  /// 琥珀:克制的金棕(70°,彩度 0.082,L 0.54)。页面转成米白纸、深色转成
  /// 暖炭,彩度只留七成半;光晕配杏粉。
  static const amber = AppAccent(
    id: 'amber',
    seed: Color(0xFF8D6636),
    pressed: Color(0xFF7A5528),
    container: Color(0xFFF2E6D9),
    onContainer: Color(0xFF483011),
    bubble: Color(0xFFEEE2D3),
    glow: Color(0xFFDCBE9D),
    seedDark: Color(0xFFCCAC87),
    pressedDark: Color(0xFFB99975),
    onSeedDark: Color(0xFF271A0C),
    containerDark: Color(0xFF4C3A25),
    onContainerDark: Color(0xFFEADFD3),
    bubbleDark: Color(0xFF392F24),
    glowDark: Color(0xFF7F6343),
    tintHue: 75,
    tintChroma: 0.75,
    haze: Color(0xFFEAC8C1),
    hazeDark: Color(0xFF64443D),
  );

  /// 石墨:**默认档**。中性灰,主色在浅色里近黑、深色里近白,
  /// 中性色零彩度。数值对齐官方 `--color-background-primary-solid`
  /// (浅 gray-900 / 深 gray-950)与 `--color-surface` 阶梯。
  static const graphite = AppAccent(
    id: 'graphite',
    seed: Color(0xFF181818),
    pressed: Color(0xFF0D0D0D),
    container: Color(0xFFF3F3F3),
    onContainer: Color(0xFF0D0D0D),
    bubble: Color(0x0D0D0D0D),
    glow: Color(0xFFFFFFFF),
    seedDark: Color(0xFFF3F3F3),
    pressedDark: Color(0xFFECECEC),
    onSeedDark: Color(0xFF0D0D0D),
    containerDark: Color(0xFF303030),
    onContainerDark: Color(0xFFECECEC),
    bubbleDark: Color(0xFF2F2F2F),
    glowDark: Color(0xFF212121),
    // 中性色不染色:零彩度。[NeutralTones.of] 对 c=0 只乘不除,数学安全
    // (test/theme/official_palette_test.dart 逐格钉死)。
    tintHue: NeutralTones.baseHue,
    tintChroma: 0,
    haze: Color(0xFFFFFFFF),
    hazeDark: Color(0xFF212121),
  );

  /// 设置页里的顺序。
  static const presets = [mist, daiqing, dusk, turquoise, amber, graphite];

  /// ChatGPT 官方十色强调色板（2026-11-09 从 App 截图逐像素实测）。
  ///
  /// 每色两套值：`seed` 浅色模式、`seedDark` 深色模式——官方在两种模式下
  /// 用的是**不同**的 hex，不是同一个种子自动推导。
  ///
  /// 其余角色（pressed / container / bubble / glow / haze ...）由
  /// [derive] 的 OKLCH 规则按 seed 推出，保证对比度守卫仍然成立。
  ///
  /// 第十色 white/black 是"反色"：深色模式白、浅色模式黑——即 [graphite]。
  static const official = <AppAccent>[
    _officialBlue,
    _officialCyan,
    _officialGreen,
    _officialLime,
    _officialYellow,
    _officialOrange,
    _officialPink,
    _officialMagenta,
    _officialPurple,
    graphite,
  ];

  static const _officialBlue = AppAccent(
    id: 'official_blue',
    seed: Color(0xFF3566ED),
    pressed: Color(0xFF2A55CC),
    container: Color(0xFFDDE5FD),
    onContainer: Color(0xFF14265C),
    bubble: Color(0xFFD8E2FC),
    glow: Color(0xFF9DB8F8),
    seedDark: Color(0xFF3463E6),
    pressedDark: Color(0xFF2B54C8),
    onSeedDark: Color(0xFF0A1430),
    containerDark: Color(0xFF2A3557),
    onContainerDark: Color(0xFFDCE4FB),
    bubbleDark: Color(0xFF242C42),
    glowDark: Color(0xFF4A67A8),
    tintHue: 225,
    tintChroma: 0.9,
    haze: Color(0xFFC7D2F0),
    hazeDark: Color(0xFF3F4C6B),
  );

  static const _officialCyan = AppAccent(
    id: 'official_cyan',
    seed: Color(0xFF0BB4FD),
    pressed: Color(0xFF0991CE),
    container: Color(0xFFD6F1FE),
    onContainer: Color(0xFF053849),
    bubble: Color(0xFFD1EEFC),
    glow: Color(0xFF8AD8FB),
    seedDark: Color(0xFF01ABF5),
    pressedDark: Color(0xFF0190CF),
    onSeedDark: Color(0xFF021E2A),
    containerDark: Color(0xFF17414F),
    onContainerDark: Color(0xFFD5F0FC),
    bubbleDark: Color(0xFF1B333D),
    glowDark: Color(0xFF2A6E8A),
    tintHue: 200,
    tintChroma: 0.95,
    haze: Color(0xFFBFE6F5),
    hazeDark: Color(0xFF2F5566),
  );

  static const _officialGreen = AppAccent(
    id: 'official_green',
    seed: Color(0xFF0EBDA3),
    pressed: Color(0xFF0B9A85),
    container: Color(0xFFD5F5EF),
    onContainer: Color(0xFF04423A),
    bubble: Color(0xFFD0F1EB),
    glow: Color(0xFF88DFD1),
    seedDark: Color(0xFF05B499),
    pressedDark: Color(0xFF049882),
    onSeedDark: Color(0xFF031F1B),
    containerDark: Color(0xFF16443E),
    onContainerDark: Color(0xFFD4F3ED),
    bubbleDark: Color(0xFF1A3431),
    glowDark: Color(0xFF277A6D),
    tintHue: 172,
    tintChroma: 0.9,
    haze: Color(0xFFBFE9E2),
    hazeDark: Color(0xFF2C5852),
  );

  static const _officialLime = AppAccent(
    id: 'official_lime',
    seed: Color(0xFFB9D814),
    pressed: Color(0xFF99B210),
    container: Color(0xFFF3F9D2),
    onContainer: Color(0xFF3D4705),
    bubble: Color(0xFFEFF6CD),
    glow: Color(0xFFD8E98A),
    seedDark: Color(0xFFAFCF0A),
    pressedDark: Color(0xFF94AF08),
    onSeedDark: Color(0xFF202602),
    containerDark: Color(0xFF454E18),
    onContainerDark: Color(0xFFF1F7CE),
    bubbleDark: Color(0xFF2E331B),
    glowDark: Color(0xFF7A8A2E),
    tintHue: 68,
    tintChroma: 0.8,
    haze: Color(0xFFE9EDBF),
    hazeDark: Color(0xFF565C33),
  );

  static const _officialYellow = AppAccent(
    id: 'official_yellow',
    seed: Color(0xFFFECD3E),
    pressed: Color(0xFFD9AE31),
    container: Color(0xFFFFF6DC),
    onContainer: Color(0xFF4D3B08),
    bubble: Color(0xFFFCF2D6),
    glow: Color(0xFFF7DE94),
    seedDark: Color(0xFFF4C335),
    pressedDark: Color(0xFFD2A72B),
    onSeedDark: Color(0xFF2A1F04),
    containerDark: Color(0xFF52441C),
    onContainerDark: Color(0xFFFFF4D8),
    bubbleDark: Color(0xFF39321E),
    glowDark: Color(0xFF9C8137),
    tintHue: 48,
    tintChroma: 0.8,
    haze: Color(0xFFF2E5C4),
    hazeDark: Color(0xFF615436),
  );

  static const _officialOrange = AppAccent(
    id: 'official_orange',
    seed: Color(0xFFFE8066),
    pressed: Color(0xFFD96C56),
    container: Color(0xFFFFE4DE),
    onContainer: Color(0xFF4D1A10),
    bubble: Color(0xFFFCDFD8),
    glow: Color(0xFFF5AE9C),
    seedDark: Color(0xFFF57B63),
    pressedDark: Color(0xFFD26853),
    onSeedDark: Color(0xFF2A0D07),
    containerDark: Color(0xFF543028),
    onContainerDark: Color(0xFFFFE3DC),
    bubbleDark: Color(0xFF3A2723),
    glowDark: Color(0xFF9C5C4C),
    tintHue: 12,
    tintChroma: 0.85,
    haze: Color(0xFFF2D3C9),
    hazeDark: Color(0xFF62463D),
  );

  static const _officialPink = AppAccent(
    id: 'official_pink',
    seed: Color(0xFFF970AA),
    pressed: Color(0xFFD35F91),
    container: Color(0xFFFFE2EE),
    onContainer: Color(0xFF4D122C),
    bubble: Color(0xFFFCDDE9),
    glow: Color(0xFFF7A9C6),
    seedDark: Color(0xFFF06CA4),
    pressedDark: Color(0xFFCC5C8B),
    onSeedDark: Color(0xFF2A0A18),
    containerDark: Color(0xFF52283A),
    onContainerDark: Color(0xFFFFE1EC),
    bubbleDark: Color(0xFF39222C),
    glowDark: Color(0xFF9A5573),
    tintHue: 335,
    tintChroma: 0.85,
    haze: Color(0xFFF2CFDD),
    hazeDark: Color(0xFF614252),
  );

  static const _officialMagenta = AppAccent(
    id: 'official_magenta',
    seed: Color(0xFFDB69DC),
    pressed: Color(0xFFB857B9),
    container: Color(0xFFFBE0FB),
    onContainer: Color(0xFF491149),
    bubble: Color(0xFFF7DBF7),
    glow: Color(0xFFEBA0EB),
    seedDark: Color(0xFFD366D4),
    pressedDark: Color(0xFFB056B1),
    onSeedDark: Color(0xFF280928),
    containerDark: Color(0xFF502850),
    onContainerDark: Color(0xFFFBDFFB),
    bubbleDark: Color(0xFF372237),
    glowDark: Color(0xFF8F5490),
    tintHue: 300,
    tintChroma: 0.85,
    haze: Color(0xFFEDCBED),
    hazeDark: Color(0xFF5C3F5C),
  );

  static const _officialPurple = AppAccent(
    id: 'official_purple',
    seed: Color(0xFFA15BFD),
    pressed: Color(0xFF894CD7),
    container: Color(0xFFEDE0FF),
    onContainer: Color(0xFF2E1152),
    bubble: Color(0xFFE8DBFB),
    glow: Color(0xFFC9A6F7),
    seedDark: Color(0xFF9C58F5),
    pressedDark: Color(0xFF854AD1),
    onSeedDark: Color(0xFF190829),
    containerDark: Color(0xFF3D2A57),
    onContainerDark: Color(0xFFECDFFF),
    bubbleDark: Color(0xFF2F243D),
    glowDark: Color(0xFF6F4E9C),
    tintHue: 275,
    tintChroma: 0.9,
    haze: Color(0xFFDCCBF0),
    hazeDark: Color(0xFF4E3D66),
  );

  static const customId = 'custom';
  static const wallpaperId = 'wallpaper';

  /// 按 [id] 取预设;未知 / 缺失回退石墨(向前兼容旧值)。
  ///
  /// 石墨是默认档:它的色值就是 [DshPalette] 的中性灰阶,所以"用户没存过
  /// 偏好"和"用户选了石墨"看到的是同一套颜色。
  static AppAccent preset(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    // 官方十色是独立的列表（设置页默认展示这一组），但 id 同样要能解析回具体的
    // 色板——否则选了 official_blue 会静默回退到石墨，界面上"点了没反应"。
    for (final p in official) {
      if (p.id == id) return p;
    }
    return graphite;
  }

  // ══ 现推:自定义、跟随壁纸 ═══════════════════════════════════════════

  /// 强调彩度上限:再高就不"静"了(雾蓝 0.125)。
  static const maxChroma = 0.13;

  /// 色相条、推荐色的明度(与雾蓝相同)。
  static const lightSeedL = 0.53;

  /// 深色主色比浅色主色亮多少(雾蓝 0.53 → 0.764)。
  static const darkLift = 0.234;

  /// 由任意一个颜色推出整套配色:取它的色相、彩度(封顶 [maxChroma])和
  /// 明度(限在 0.30–0.60,深色再提 [darkLift]),按上面那张表推出各个
  /// 角色;浅色、深色主色各过一次 [guard],离原色最近地调到达标。
  ///
  /// 中性色转到同一色相,彩度按强调彩度折算(近灰的颜色得到近灰的页面)。
  factory AppAccent.derive(Color pick, {String id = customId, String? label}) {
    final key = (pick.toARGB32(), id, label);
    final hit = _derived[key];
    if (hit != null) return hit;
    if (_derived.length > 64) _derived.clear();
    return _derived[key] = AppAccent._derive(pick, id: id, label: label);
  }

  static final _derived = <(int, String, String?), AppAccent>{};

  factory AppAccent._derive(Color pick, {required String id, required String? label}) {
    final o = Oklch.fromColor(pick);
    final c = math.min(o.c, maxChroma);
    final h = o.h;
    final k = math.min(1.0, c / 0.1255);
    final tintChroma = 0.8 * k;
    final neutrals = NeutralTones.of(tintHue: h, tintChroma: tintChroma);
    Color tone(double l, double ratio) => Oklch(l, c * ratio, h).toColor();

    final onSeedDark = tone(0.231, 0.39);
    final lightL = o.l.clamp(0.30, 0.60);
    final seed = guard(
      Oklch(lightL, c, h),
      brightness: Brightness.light,
      surface: neutrals.mistHighest,
      onAccent: const Color(0xFFFFFFFF),
    );
    final seedDark = guard(
      Oklch(math.min(0.93, lightL + darkLift), c * 0.76, h),
      brightness: Brightness.dark,
      surface: neutrals.nightHighest,
      onAccent: onSeedDark,
    );
    final sl = Oklch.fromColor(seed).l;
    final sdl = Oklch.fromColor(seedDark).l;
    return AppAccent(
      id: id,
      label: label,
      seed: seed,
      pressed: tone(sl - 0.06, 0.95),
      container: tone(0.93, 0.26),
      onContainer: tone(0.33, 0.70),
      bubble: tone(0.918, 0.29),
      glow: tone(0.819, 0.68),
      seedDark: seedDark,
      pressedDark: tone(sdl - 0.06, 0.76),
      onSeedDark: onSeedDark,
      containerDark: tone(0.361, 0.51),
      onContainerDark: tone(0.909, 0.24),
      bubbleDark: tone(0.314, 0.29),
      glowDark: tone(0.52, 0.72),
      tintHue: h,
      tintChroma: tintChroma,
      haze: Oklch(0.86, 0.045 * k, h + 33).toColor(),
      hazeDark: Oklch(0.42, 0.05 * k, h + 33).toColor(),
    );
  }

  /// 强调色在底面上的最低对比度(WCAG 1.4.11 非文字)。
  static const minOnSurface = 3.0;

  /// 强调色上文字的最低对比度(WCAG 1.4.3 正文)。
  static const minText = 4.5;

  /// 对比度守卫:色相、彩度不动,只沿明度移动 [start],直到
  ///
  /// - 强调色对 [surface] ≥ [minOnSurface](3:1),且
  /// - [onAccent] 对强调色 ≥ [minText](4.5:1)。
  ///
  /// 浅色往暗处走(白字在上),深色往亮处走(深墨字在上);已经达标就原样
  /// 返回。二分 24 步,停在离起点最近的达标明度上。
  static Color guard(Oklch start, {required Brightness brightness, required Color surface, required Color onAccent}) {
    bool ok(Color c) => contrastRatio(c, surface) >= minOnSurface && contrastRatio(onAccent, c) >= minText;
    final first = start.toColor();
    if (ok(first)) return first;
    final dark = brightness == Brightness.dark;
    // 浅色:在 [0, start.l] 里找最大的达标明度;深色:在 [start.l, 1] 里找最小的。
    var pass = dark ? 1.0 : 0.0;
    var fail = start.l;
    for (var i = 0; i < 24; i++) {
      final mid = (pass + fail) / 2;
      if (ok(start.copyWith(l: mid).toColor())) {
        pass = mid;
      } else {
        fail = mid;
      }
    }
    return start.copyWith(l: pass).toColor();
  }

  /// [pick] 在 [brightness] 下守卫后的主色:设置页的色块和色相条直接画它。
  static Color guardedSeed(Color pick, Brightness brightness) => AppAccent.derive(pick).seedFor(brightness);

  /// 色相条 / 推荐色用的颜色:[hue] 度、雾蓝的彩度和明度。
  static Color hueColor(double hue, {double chroma = 0.11}) => Oklch(lightSeedL, chroma, hue).toColor();

  @override
  bool operator ==(Object other) =>
      other is AppAccent &&
      other.id == id &&
      other.seed == seed &&
      other.seedDark == seedDark &&
      other.tintHue == tintHue &&
      other.tintChroma == tintChroma;

  @override
  int get hashCode => Object.hash(id, seed, seedDark, tintHue, tintChroma);

  @override
  String toString() => 'AppAccent($id)';
}
