// 聊天空态的品牌改版（2026-11-10）。
//
// 这一组是**独立的**新基准，不复用 `empty_actions_test.dart` 的 golden：
// 空态从「一句大标题」改成「鲸尾 + 时段问候 + 四张能力卡」是产品决定，不是回归。
// 旧 golden 保持原样，它测的是 SuggestionCards 的几何，仍然有效。
//
// 守住四件事：
//   1. 品牌形与问候语真的出现，且鲸尾是静帧；
//   2. 四张能力卡是 PlugHarness 的能力入口，不是通用开发任务；
//   3. 320 窄屏 / 915×412 矮横屏 / 1.3× 字号下不溢出；
//   4. 连不上引擎时品牌形和卡片都收起。
import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/ui/chat/empty_state.dart';
import 'package:dsh_app/ui/chat/widgets/whale_tail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

ChatEmptyState _empty({bool connected = true, String? workspace = 'my-project'}) => ChatEmptyState(
  connected: connected,
  workspace: workspace,
  onWorkspace: () {},
  onSuggestion: (_) {},
);

/// 与 chat_screen 里一致的承载方式，让几何与真实页面同源。
Widget _host(Widget child, {Brightness brightness = Brightness.light, Size size = const Size(390, 844), double textScale = 1.0}) =>
    MaterialApp(
      theme: testTheme(brightness),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  // 问候随时段走：固定时钟，逐档钉死。
  group('greeting follows the hour', () {
    final cases = <int, String>{
      6: '早上好',
      12: '中午好',
      15: '下午好',
      20: '晚上好',
      2: '夜深了',
    };
    for (final entry in cases.entries) {
      test('${entry.key}:00 → ${entry.value}', () {
        expect(greetingFor(DateTime(2026, 11, 10, entry.key)), entry.value);
      });
    }
  });

  testWidgets('the whale and a greeting are both on the new-chat screen', (tester) async {
    await tester.pumpWidget(_host(_empty()));
    await tester.pumpAndSettle();

    // 品牌形：静止的鲸尾，不跑计时器。
    expect(find.byType(WhaleTail), findsOneWidget);
    expect(tester.widget<WhaleTail>(find.byType(WhaleTail)).still, isTrue,
        reason: '这一屏的鲸尾必须是静帧，不能和输入框抢注意力');

    // 恰好一种问候语在屏幕上（真实时钟，所以不钉死是哪一种）。
    final greetings = [
      appL10n.viewGreetingMorning,
      appL10n.viewGreetingNoon,
      appL10n.viewGreetingAfternoon,
      appL10n.viewGreetingEvening,
      appL10n.viewGreetingNight,
    ];
    expect(greetings.where((g) => find.text(g).evaluate().isNotEmpty), hasLength(1));
    expect(find.text(appL10n.viewEmptyTitle), findsNothing,
        reason: '连接正常时不该再显示固定的「有什么可以帮你？」');
  });

  testWidgets('the four suggestions are PlugHarness capabilities', (tester) async {
    await tester.pumpWidget(_host(_empty()));
    await tester.pumpAndSettle();

    expect(defaultSuggestions.map((s) => s.label), [
      appL10n.viewSuggestPhone,
      appL10n.viewSuggestPlugin,
      appL10n.viewSuggestWorkspace,
      appL10n.viewSuggestSchedule,
    ]);
    for (final s in defaultSuggestions) {
      expect(find.text(s.label), findsOneWidget);
      expect(s.prompt, isNotEmpty, reason: '${s.label} 点了要能填进输入框');
      expect(s.detail, isNotNull, reason: '${s.label} 要说明它替你做什么');
    }
  });

  testWidgets('disconnected hides the whale and folds the suggestions away', (tester) async {
    await tester.pumpWidget(_host(_empty(connected: false)));
    await tester.pumpAndSettle();

    expect(find.byType(WhaleTail), findsNothing, reason: '这一屏只该有「重新连接」');
    expect(find.text(appL10n.viewEmptyTitle), findsOneWidget, reason: '连不上时说清是什么状态');
  });

  testWidgets('a 320dp phone keeps every card on screen', (tester) async {
    await tester.pumpWidget(_host(_empty(), size: const Size(320, 568)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final s in defaultSuggestions) {
      expect(find.text(s.label), findsOneWidget);
    }
  });

  testWidgets('a landscape phone (915x412) drops the whale to keep the cards', (tester) async {
    await tester.pumpWidget(_host(_empty(), size: const Size(915, 412)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WhaleTail), findsNothing, reason: '矮横屏纵向不够，品牌形让位给建议卡');
    expect(find.text(defaultSuggestions.first.label), findsOneWidget);
  });

  testWidgets('1.3x text does not overflow', (tester) async {
    await tester.pumpWidget(_host(_empty(), textScale: 1.3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final s in defaultSuggestions) {
      expect(find.text(s.label), findsOneWidget);
    }
  });

  // 新的 golden 基准：浅色 + 深色各一张，390×844。
  // 与旧 golden 无关——删掉旧基准不影响这组，反之亦然。
  for (final brightness in Brightness.values) {
    testWidgets('golden: new-chat brand screen (${brightness.name})', (tester) async {
      await tester.pumpWidget(_host(_empty(), brightness: brightness));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ChatEmptyState),
        matchesGoldenFile('goldens/empty_state_brand_${brightness.name}.png'),
      );
    });
  }
}