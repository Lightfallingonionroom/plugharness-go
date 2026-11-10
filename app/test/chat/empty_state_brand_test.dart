// 聊天空态的品牌改版（2026-11-10，2026-11-11 精简）。
//
// 空态的结构变过两次：
//   1. 2026-10：一句大标题 + 四张能力卡 + 小技巧；
//   2. 2026-11-10：鲸尾 + 时段问候 + 同样的卡片；
//   3. 2026-11-11：**卡片和小技巧删掉**（用户要求 ChatGPT 式的一屏一句标题）。
//
// 这一组现在只守住三件事：
//   1. 品牌形与问候语真的出现，且鲸尾是静帧；
//   2. 320 窄屏 / 915×412 矮横屏 / 1.3× 字号下不溢出；
//   3. 连不上引擎时品牌形收起。
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

  testWidgets('disconnected hides the whale', (tester) async {
    await tester.pumpWidget(_host(_empty(connected: false)));
    await tester.pumpAndSettle();

    expect(find.byType(WhaleTail), findsNothing, reason: '这一屏只该有「重新连接」');
    expect(find.text(appL10n.viewEmptyTitle), findsOneWidget, reason: '连不上时说清是什么状态');
  });

  testWidgets('a 320dp phone keeps the screen usable', (tester) async {
    await tester.pumpWidget(_host(_empty(), size: const Size(320, 568)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a landscape phone (915x412) drops the whale', (tester) async {
    await tester.pumpWidget(_host(_empty(), size: const Size(915, 412)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WhaleTail), findsNothing, reason: '矮横屏纵向不够，品牌形让位');
  });

  testWidgets('1.3x text does not overflow', (tester) async {
    await tester.pumpWidget(_host(_empty(), textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // 新的 golden 基准：浅色 + 深色各一张，390×844。
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