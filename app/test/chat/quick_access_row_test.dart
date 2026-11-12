// Quick-access row: collapsed dots, expanded capsules, disabled new-chat state.
// The row owns only its own state; routes are injected by the caller, so these
// tests can count taps without a session or a host.

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/ui/chat/quick_access_row.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({required bool enabled, required void Function(String) onAction}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Scaffold(
          body: Center(
            child: QuickAccessRow(
              enabled: enabled,
              disabledHint: 'start a chat first',
              onTerminal: () => onAction('terminal'),
              onTeam: () => onAction('team'),
              onFiles: () => onAction('files'),
            ),
          ),
        ),
      );

  testWidgets('collapsed shows three dots; tapping expands to three capsules', (tester) async {
    await tester.pumpWidget(wrap(enabled: true, onAction: (_) {}));
    expect(find.byKey(QuickAccessKeys.collapsed), findsOneWidget);
    expect(find.byKey(QuickAccessKeys.expanded), findsNothing);
    expect(find.byKey(QuickAccessKeys.terminal), findsNothing);
    expect(find.byKey(QuickAccessKeys.open), findsOneWidget);
    expect(find.byKey(QuickAccessKeys.close), findsNothing);

    await tester.tap(find.byKey(QuickAccessKeys.open));
    await tester.pumpAndSettle();

    expect(find.byKey(QuickAccessKeys.expanded), findsOneWidget);
    expect(find.byKey(QuickAccessKeys.terminal), findsOneWidget);
    expect(find.byKey(QuickAccessKeys.team), findsOneWidget);
    expect(find.byKey(QuickAccessKeys.files), findsOneWidget);
    // The open and close keys must never coexist, or a fast double tap would
    // hit two widgets and the finder would throw.
    expect(find.byKey(QuickAccessKeys.open), findsNothing);
    expect(find.byKey(QuickAccessKeys.close), findsOneWidget);
  });

  testWidgets('each capsule fires its own action, then the row closes on close', (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(wrap(enabled: true, onAction: hits.add));
    await tester.tap(find.byKey(QuickAccessKeys.open));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuickAccessKeys.terminal));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuickAccessKeys.team));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuickAccessKeys.files));
    await tester.pumpAndSettle();
    expect(hits, ['terminal', 'team', 'files']);

    await tester.tap(find.byKey(QuickAccessKeys.close));
    await tester.pumpAndSettle();
    expect(find.byKey(QuickAccessKeys.collapsed), findsOneWidget);
  });

  testWidgets('a new chat keeps the buttons visible but disabled, with no route', (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(wrap(enabled: false, onAction: hits.add));
    await tester.tap(find.byKey(QuickAccessKeys.open));
    await tester.pumpAndSettle();

    for (final key in [QuickAccessKeys.terminal, QuickAccessKeys.team, QuickAccessKeys.files]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key stays visible on a new chat');
    }
    await tester.tap(find.byKey(QuickAccessKeys.terminal));
    await tester.tap(find.byKey(QuickAccessKeys.team));
    await tester.tap(find.byKey(QuickAccessKeys.files));
    await tester.pumpAndSettle();
    expect(hits, isEmpty, reason: 'no createSession RPC, no route, no draft mutation');
  });

  testWidgets('the row height is the same collapsed and expanded', (tester) async {
    await tester.pumpWidget(wrap(enabled: true, onAction: (_) {}));
    final collapsed = tester.getSize(find.byKey(QuickAccessKeys.root));
    await tester.tap(find.byKey(QuickAccessKeys.open));
    await tester.pumpAndSettle();
    final expanded = tester.getSize(find.byKey(QuickAccessKeys.root));
    expect(expanded.height, collapsed.height);
  });

  testWidgets('expanded capsules fit a 320dp viewport at large text scale', (tester) async {
    // Same view setup as access_geometry_test / chat_header_geometry_test.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(640, 1280); // 320 x 640 dp
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(wrap(enabled: true, onAction: (_) {}));
    await tester.tap(find.byKey(QuickAccessKeys.open));
    await tester.pumpAndSettle();

    final row = tester.getRect(find.byKey(QuickAccessKeys.expanded));
    expect(row.left, greaterThanOrEqualTo(0));
    expect(row.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
  });
}