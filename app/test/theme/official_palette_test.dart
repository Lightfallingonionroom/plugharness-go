// The shell's neutral palette is pinned to the official ChatGPT tokens
// (openai/apps-sdk-ui `--gray-*`, docs/openai-sdk-ui-spec.md §3) and to the
// 石墨 preset that carries them. Changing one without the others is the bug
// this file exists to catch: the chat shell reads `ChatGptShellColors`, every
// other surface reads `DshColors`/`DshSurfaces`, so a change to only one side
// leaves settings looking like the old app.
//
// Values are checked against the official table, not against each other.

import 'package:dsh_app/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The official `--gray-*` scale (dark) from docs/openai-sdk-ui-spec.md §3.
///
/// `textTertiary` (gray-600) is deliberately **not** used as-is: 0xFF8F8F8F
/// gives only 3.57:1 on nightHighest, under WCAG AA's 4.5:1. The app ships
/// 0xFFA3A3A3 instead (5.38:1). See the note where the assertion was changed.
const _officialDark = <String, int>{
  'surface': 0xFF212121, // gray-200
  'surfaceSecondary': 0xFF181818, // gray-100
  'surfaceTertiary': 0xFF131313, // gray-50
  'surfaceElevated': 0xFF303030, // gray-300
  'text': 0xFFECECEC, // gray-900
  'textSecondary': 0xFFAFAFAF, // gray-700
  'backgroundPrimarySolid': 0xFFF3F3F3, // gray-950
  'backgroundPrimarySolidText': 0xFF0D0D0D, // gray-0
};

void main() {
  test('the dark neutral scale is the official gray ramp, with no blue cast', () {
    final n = NeutralTones.defaults;
    expect(n.night, Color(_officialDark['surface']!));
    expect(n.nightLowest, const Color(0xFF171717), reason: 'one step below the sidebar');
    expect(n.nightContainer, Color(_officialDark['surfaceElevated']!));
    expect(n.paper, Color(_officialDark['text']!));
    expect(n.paperMuted, Color(_officialDark['textSecondary']!));
    // 2026-11-11: textTertiary 从官方 gray-600(#8F8F8F) 提到 #A3A3A3。
    // 官方值对 nightHighest(#393939) 只有 3.57:1，够不上 WCAG AA 的 4.5:1
    // （palette_contrast_test 78 条失败）。#A3A3A3 是 5.38:1。
    // 这是**有意偏离官方令牌**，理由是可访问性；其余中性色仍与官方一致。
    expect(n.paperFaint, const Color(0xFFA3A3A3));
    expect(n.sheetDark, Color(_officialDark['surfaceElevated']!));

    // No blue cast: R == G == B on every neutral (the old palette was blue-tinted).
    final neutrals = {
      'night': n.night,
      'nightTop': n.nightTop,
      'nightBottom': n.nightBottom,
      'nightLowest': n.nightLowest,
      'nightContainer': n.nightContainer,
      'paper': n.paper,
      'paperMuted': n.paperMuted,
      'paperFaint': n.paperFaint,
      'ruleDark': n.ruleDark,
      'sheetDark': n.sheetDark,
    };
    for (final entry in neutrals.entries) {
      final name = entry.key;
      final c = entry.value;
      expect(c.r, c.g, reason: '$name must be neutral (R == G): $c');
      expect(c.g, c.b, reason: '$name must be neutral (G == B): $c');
      expect(Oklch.fromColor(c).c, lessThan(0.002), reason: '$name must be achromatic: $c');
    }
  });

  test('the light neutral scale is the official gray ramp', () {
    final n = NeutralTones.defaults;
    expect(n.mist, const Color(0xFFFFFFFF));
    expect(n.mistTop, const Color(0xFFFFFFFF));
    expect(n.mistBottom, const Color(0xFFFFFFFF));
    expect(n.mistLow, const Color(0xFFF9F9F9));
    expect(n.mistContainer, const Color(0xFFF3F3F3));
    expect(n.ink, const Color(0xFF0D0D0D));
    expect(n.inkMuted, const Color(0xFF5D5D5D));
    // 同上：对可访问性让路，从官方 gray-600 压到 #757575（白底 4.61:1）。
    expect(n.inkFaint, const Color(0xFF757575));
    expect(n.ruleLight, const Color(0xFFE5E5E5));
  });

  test('graphite is the default preset and carries the official solid action', () {
    expect(AppAccent.preset(null).id, 'graphite');
    expect(AppAccent.preset('bogus').id, 'graphite');
    const g = AppAccent.graphite;
    expect(g.seedDark, Color(_officialDark['backgroundPrimarySolid']!));
    expect(g.onSeedDark, Color(_officialDark['backgroundPrimarySolidText']!));
    expect(g.tintChroma, 0, reason: 'zero chroma: the neutrals are not tinted');
  });

  test('tintChroma 0 is mathematically safe and reproduces the grey ramp', () {
    // Zero chroma must not divide, NaN or throw anywhere in the derivation.
    final n = NeutralTones.of(tintHue: NeutralTones.baseHue, tintChroma: 0);
    for (final c in [
      n.night,
      n.nightContainer,
      n.paper,
      n.ruleDark,
      n.smoke,
      n.sheetDark,
      n.codeWellDark,
      n.inverseSurface,
    ]) {
      expect(c.toARGB32(), isNot(0), reason: 'a zeroed colour is a bug: $c');
      expect(c.r, c.g, reason: 'achromatic: $c');
      expect(c.g, c.b, reason: 'achromatic: $c');
    }
    // The ramp survives the OKLCH round trip with no drift (the probe measured 0).
    expect(n.nightLowest, const Color(0xFF171717));
    expect(n.nightContainer, const Color(0xFF303030));
  });

  test('both halves of the shell agree: chat shell vs the rest of the app', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();
    final shellDark = ChatGptShellColors.dark(AppAccent.graphite);
    final surfacesDark = dark.extension<DshSurfaces>()!;

    // The page colour is the same colour on both sides (that was the split).
    expect(surfacesDark.backdropTop, shellDark.page);
    expect(dark.colorScheme.surface, shellDark.page);
    expect(light.colorScheme.surface, ChatGptShellColors.light(AppAccent.graphite).page);

    // The dark action is the official near-white solid on both sides.
    expect(dark.colorScheme.primary, shellDark.primaryAction);
    expect(dark.colorScheme.onPrimary, shellDark.onPrimaryAction);

    // Text tiers agree between the shared extension and the chat shell.
    expect(dark.colorScheme.onSurface, shellDark.primaryText);
    expect(dark.colorScheme.onSurfaceVariant, shellDark.secondaryText);
    expect(dark.extension<DshColors>()!.textTertiary, shellDark.tertiaryText);
  });

  test('picking an accent actually repaints the shell, and both halves stay in step', () {
    // The bug this pins: the neutral scale is R==G==B, so `c * chromaScale` was
    // still 0 and every accent produced the exact same page, sidebar and text.
    // Picking a colour changed the buttons and nothing else.
    final graphite = ChatGptShellColors.light(AppAccent.graphite);
    final blue = ChatGptShellColors.light(AppAccent.preset('official_blue'));
    final orange = ChatGptShellColors.light(AppAccent.preset('official_orange'));
    expect(blue.page, isNot(graphite.page), reason: 'blue must move the page off plain white');
    expect(orange.page, isNot(graphite.page), reason: 'orange must move the page too');
    expect(blue.page, isNot(orange.page), reason: 'blue and orange must not land on one colour');

    // And the accent must reach the secondary pages the same way, or the chat
    // screen and 设置 read as two different apps.
    for (final accent in [...AppAccent.presets, ...AppAccent.official]) {
      final surfaces = DshSurfaces.light(accent);
      final shell = ChatGptShellColors.light(accent);
      final darkSurfaces = DshSurfaces.dark(accent);
      final shellDarkForAccent = ChatGptShellColors.dark(accent);
      expect(surfaces.backdropTop, shell.page, reason: 'light page agrees for ${accent.id}');
      expect(darkSurfaces.backdropTop, shellDarkForAccent.page, reason: 'dark page agrees for ${accent.id}');
    }
  });

  test('the official palette test itself: contrast still holds on the grey ramp', () {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final theme = dark ? buildDarkTheme() : buildLightTheme();
      final scheme = theme.colorScheme;
      final s = theme.extension<DshSurfaces>()!;
      final card = Color.alphaBlend(s.card.fill, s.backdropTop);
      expect(contrastRatio(scheme.onSurface, s.backdropTop), greaterThanOrEqualTo(10));
      expect(contrastRatio(scheme.onSurfaceVariant, s.backdropTop), greaterThanOrEqualTo(6));
      expect(contrastRatio(scheme.primary, card), greaterThanOrEqualTo(3));
      expect(contrastRatio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
    }
  });
}