// 快捷入口 used to be a second panel pulled in from the right by a left swipe,
// the mirror of the drawer's own swipe. Its destinations are rows in the
// drawer's column now (ChatGPT's one-column layout), so there is no panel to
// pull: a left swipe over the chat must leave it closed, and every destination
// must be reachable from the drawer.
//
//   flutter test test/shell/quick_panel_test.dart

import 'dart:ui' show GestureSettings;

import 'package:dsh_app/state/adaptive_layout_state.dart';
import 'package:dsh_app/state/quick_panel_state.dart';
import 'package:dsh_app/ui/shell/home_shell.dart';
import 'package:dsh_app/ui/shell/quick_panel.dart';
import 'package:dsh_app/ui/shell/sessions_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/support/harness.dart';
import 'adaptive/support.dart';

const _phone = Size(390, 844);

void _androidSlop(WidgetTester tester) => tester.view.gestureSettings = const GestureSettings(physicalTouchSlop: 16);

Future<void> _pump(WidgetTester tester, {LayoutPrefs prefs = const LayoutPrefs(loaded: true)}) async {
  useWindow(tester, _phone);
  _androidSlop(tester);
  mockClipboard(tester);
  await tester.pumpWidget(homeApp(prefs: prefs));
  await pumpFrames(tester, 8);
}

/// Down at [from], [steps] moves of [by], a pause (no fling), up, settled.
Future<void> _swipe(WidgetTester tester, Offset from, Offset by, {int steps = 40}) async {
  final finger = await tester.startGesture(from);
  for (var i = 0; i < steps; i++) {
    await finger.moveBy(by);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await finger.up();
  await pumpFrames(tester, 8);
}

const _chatMiddle = Offset(195, 420);

Finder get _panel => find.byType(QuickPanel);
Finder get _drawer => find.byType(SessionsDrawer);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeShell, skipOffstage: false)));

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    freezeClocks();
  });
  tearDown(thawClocks);

  group('the panel is gone', () {
    testWidgets('a left swipe over the chat does not open it', (tester) async {
      await _pump(tester);
      expect(_panel, findsNothing);
      await _swipe(tester, _chatMiddle, const Offset(-6, 0));
      expect(_panel, findsNothing, reason: 'the right-hand panel retired with the one-column layout');
      expect(_drawer, findsNothing, reason: 'a left swipe must not open the left drawer either');
    });

    testWidgets('no preference can bring it back', (tester) async {
      await _pump(tester);
      // The switch and the item list still exist — the drawer reads them — but
      // the panel answers "nothing to pull" whoever asks.
      expect(_container(tester).read(quickPanelProvider).available, isFalse);
    });
  });

  group('the drawer holds the destinations', () {
    testWidgets('each quick-panel row is a row of the drawer', (tester) async {
      await _pump(tester);
      // Open the drawer with its own right swipe.
      await _swipe(tester, _drawerMiddle(tester), const Offset(6, 0));
      expect(_drawer, findsOneWidget);
      // The default destinations, drawn where ChatGPT keeps them.
      for (final destination in QuickPanelPrefs.defaultItems) {
        expect(
          find.byKey(ValueKey('quick-panel-${destination.name}')),
          findsOneWidget,
          reason: '${destination.name} lives in the drawer column now',
        );
      }
    });
  });
}

/// The middle of the chat's message area on [_phone].
Offset _drawerMiddle(WidgetTester tester) => const Offset(20, 420);