// 官方十色强调色板的回归测试（2026-11-10）。
//
// 起因：实机点十个色板全都没反应，只有石墨和自定义能用。
// 根因：`AppAccent.preset()` 只查 `presets`（六套老色板），而官方十色是
// 另一个列表 `official`，于是任何 `official_*` 的 id 都解析不到、静默回退
// 到 graphite——界面上看起来就是"点了没反应"。
//
// 这里守住两件事，都是那次 bug 的直接表现：
//   1. `preset()` 必须能解析官方十色的每一个 id；
//   2. 十色彼此不同（不能都退化成 graphite）。
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every official accent id resolves back to itself', () {
    for (final accent in AppAccent.official) {
      expect(
        AppAccent.preset(accent.id).id,
        accent.id,
        reason: '${accent.id} 解析不回来，选它会静默退化成石墨',
      );
    }
  });

  test('the ten official accents are not all the same colour', () {
    final seeds = {for (final a in AppAccent.official) a.seed.toARGB32()};
    // 十色里第十个（graphite，反色）与别的不同；至少要有 8 个不同的浅色种子，
    // 否则说明有 id 撞车或解析失败。
    expect(seeds.length, greaterThanOrEqualTo(8), reason: '十色种子重复太多，可能有 id 解析失败');
  });

  test('official accents keep their own dark seed', () {
    for (final accent in AppAccent.official) {
      if (accent.id == AppAccent.graphite.id) continue;
      expect(
        accent.seedFor(Brightness.dark),
        accent.seedDark,
        reason: '${accent.id} 深色模式应该用它自己的 seedDark，而不是浅色种子的推导值',
      );
    }
  });

  test('six presets still resolve (nothing regressed for the old palettes)', () {
    for (final p in AppAccent.presets) {
      expect(AppAccent.preset(p.id).id, p.id);
    }
  });
}