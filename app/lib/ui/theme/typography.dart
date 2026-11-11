// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

/// 字体规范:**系统无衬线负责一切文字,等宽只给代码**。
///
/// ## 为什么不打包中文字体、也不用衬线标题
///
/// - 思源黑体 / 宋体单字重 10–20 MB,APK 已经背着 Linux 运行时,不能再加;
/// - 国产 ROM(MIUI/HyperOS、ColorOS、OriginOS、HarmonyOS)把系统字体换成了
///   MiSans、OPPO Sans、vivo Sans、HarmonyOS Sans,质量都很好,而且自带配套的
///   拉丁字形 —— 跟着系统走就是最协调的;
/// - 这些 ROM 普遍**没有** Noto Serif CJK,衬线标题在它们上面会变成
///   "拉丁是衬线、中文是黑体"的拼盘。所以标题用无衬线 + 字号 / 颜色分层。
///
/// ## 字重只用两档
///
/// AOSP / Pixel 只带 Noto Sans CJK **Regular** 一个字重,w500 会被就近映射回
/// Regular,w600+ 走合成加粗。所以层级只靠 400 / 600 两档 + 字号 + 颜色,
/// 不要指望 500 和 400 在中文上看得出区别。大号展示字用 300(在有多字重的
/// 系统上更轻盈,没有时退回 400,不影响阅读)。
///
/// ## 等宽
///
/// JetBrains Mono(OFL,Regular + Medium + Bold 约 0.8 MB)。Android 的
/// `monospace` 在不同机型上是 Droid Sans Mono / Cutive Mono,观感参差,代码
/// 是这个 App 的主要内容之一,值得打包。缺失时回退系统等宽。
///
/// ## 汉字字形
///
/// 中日韩统一码同一个码位在不同地区字形不同(如「直」「写」)。务必在
/// `MaterialApp` 里声明 `supportedLocales: [Locale('zh', 'CN'), ...]` 并接入
/// `GlobalMaterialLocalizations`,否则在非中文系统语言下会取到日文字形。
abstract final class AppType {
  /// 无衬线族。`null` = 系统默认(Android:Roboto + 系统中文字体)。
  /// 将来若打包拉丁 UI 字体,只改这一处。
  static const String? sansFamily = null;

  /// 打包的等宽族名(pubspec `fonts:` 里的 family)。
  static const monoFamily = 'JetBrainsMono';

  /// Source operators remain separate glyphs (<=, !=, ->), not programming
  /// ligatures. This changes shaping only, never the text copied or selected.
  static const monoFeatures = [FontFeature.disable('calt'), FontFeature.disable('liga')];

  /// 等宽回退:系统等宽 → 中文(代码注释里的中文落到系统黑体)。
  static const monoFallback = <String>['monospace', 'Noto Sans Mono CJK SC', 'Noto Sans CJK SC'];

  /// [t] with every style's glyph locale set to [locale] (null: unchanged).
  /// The English UI passes zh_CN so Chinese content keeps Chinese shapes.
  static TextTheme withGlyphLocale(TextTheme t, Locale? locale) {
    if (locale == null) return t;
    final s = TextStyle(locale: locale);
    return t.merge(
      TextTheme(
        displayLarge: s,
        displayMedium: s,
        displaySmall: s,
        headlineLarge: s,
        headlineMedium: s,
        headlineSmall: s,
        titleLarge: s,
        titleMedium: s,
        titleSmall: s,
        bodyLarge: s,
        bodyMedium: s,
        bodySmall: s,
        labelLarge: s,
        labelMedium: s,
        labelSmall: s,
      ),
    );
  }

  /// 等宽样式统一出口 —— 业务代码禁止再写 fontFamily 字面量。
  static TextStyle mono({double size = 13, FontWeight? weight, Color? color, double height = 1.55}) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFeatures: monoFeatures,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// 工具 / 终端输出正文。
  static TextStyle monoSmall({Color? color}) => mono(size: 12, color: color, height: 1.5);

  /// 参数摘要、命令行、路径 chip、diff 统计。
  static TextStyle monoLabel({Color? color, FontWeight? weight}) =>
      mono(size: 12, color: color, weight: weight, height: 1.35);

  /// 聊天正文(用户气泡与助手正文同源,流式 → 渲染完成不跳字号)。
  ///
  /// [scale] / [height] 来自用户设置(建议 scale 0.85–1.3,height 1.5–1.9);
  /// 主题本身不依赖任何状态。
  static TextStyle chatBody(BuildContext context, {double scale = 1, double? height, Color? color}) {
    final base = Theme.of(context).textTheme.bodyLarge ?? textTheme.bodyLarge!;
    return base.copyWith(fontSize: (base.fontSize ?? 16) * scale, height: height ?? base.height, color: color);
  }

  /// 欢迎语 / 空状态大字:大而轻,不靠粗。
  static TextStyle display({double size = 28, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1.25,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 字标「DSH」:无衬线粗体 + 轻微字距。
  static TextStyle wordmark({double size = 18, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );

  /// 分区小标题(「最近会话」「引擎」):小字号 + 字距,替代粗分割线。
  static TextStyle eyebrow({Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.35,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 等宽数字(计时器、token 计数、百分比),防止数字跳动导致宽度抖。
  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static const _even = TextLeadingDistribution.even;

  /// Material 3 字阶(颜色在 app_theme 里按方案统一 apply)。
  ///
  /// ## 对齐口径：OpenAI 官方设计系统（App / 源码级）
  ///
  /// 一手材料 `docs/openai-sdk-ui-spec.md`（OpenAI 官方公开的 `@openai/apps-sdk-ui`，
  /// MIT）——这是**官方 App 口径**的 token，不是网页版：
  ///
  /// ```
  /// text-2xs   10 / lh 14   w400
  /// text-xs    12 / lh 18   w400
  /// text-sm    14 / lh 20   w400
  /// text-md    16 / lh 24   w400
  /// heading-xs 16 / lh 24   w600
  /// heading-sm 18 / lh 26   w600
  /// heading-md 20 / lh 26   w600
  /// heading-lg 24 / lh 28   w600
  /// heading-xl 32 / lh 38   w600
  /// ```
  /// 字重只有 400/500/600/700，**bold 用 600**。
  ///
  /// 与网页版（`docs/CHATGPT_FONT_SPEC`）的区别：网页版 heading-2xl=36、3xl=48，
  /// **App 口径最大标题是 32（heading-xl）**。本表按 App 口径。
  ///
  /// 行高一律用官方 px 换算成比值，不再自造更松的值。
  ///
  /// | 角色 | 官方 token | 字号 / 行高 | 字重 |
  /// |---|---|---|---|
  /// | displayLarge | heading-xl | 32 / 1.19 | 600 |
  /// | displayMedium | heading-lg | 24 / 1.17 | 600 |
  /// | displaySmall | heading-lg | 24 / 1.17 | 600 |
  /// | headlineLarge | heading-lg | 24 / 1.17 | 600 |
  /// | headlineMedium | heading-md | 20 / 1.3 | 600 |
  /// | headlineSmall | heading-sm | 18 / 1.44 | 600 |
  /// | titleLarge | heading-xs | 16 / 1.5 | 600 |
  /// | titleMedium | text-md | 16 / 1.5 | 500 |
  /// | titleSmall | text-sm | 14 / 1.43 | 500 |
  /// | bodyLarge | text-md | 16 / 1.5 | 400 |
  /// | bodyMedium | text-sm | 14 / 1.43 | 400 |
  /// | bodySmall | text-xs | 12 / 1.5 | 400 |
  /// | labelLarge | text-sm | 14 / 1.43 | 500 |
  /// | labelMedium | text-xs | 12 / 1.5 | 500 |
  /// | labelSmall | text-2xs | 10 / 1.4 | 400 |
  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.19, letterSpacing: -0.4, leadingDistribution: _even),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.17, letterSpacing: -0.3, leadingDistribution: _even),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.17, letterSpacing: -0.3, leadingDistribution: _even),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.17, letterSpacing: -0.3, leadingDistribution: _even),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: _even),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.44, leadingDistribution: _even),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, leadingDistribution: _even),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, leadingDistribution: _even),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.43, leadingDistribution: _even),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, leadingDistribution: _even),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.43, leadingDistribution: _even),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, leadingDistribution: _even),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.1,
      leadingDistribution: _even,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: 0.1,
      leadingDistribution: _even,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0.2,
      leadingDistribution: _even,
    ),
  );
}
