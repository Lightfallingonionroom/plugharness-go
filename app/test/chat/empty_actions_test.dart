// The new-chat empty state — at most one primary pill (「重新连接」), the
// workspace chip under it, and the new chat's options.
//
// The suggestion cards and the tip line were removed in 2026-11 (the user asked
// for a ChatGPT-style empty state: one big title and the composer). Their
// geometry tests went with them: they measured a widget that no longer exists,
// so keeping them would be testing a fiction. `ChatSuggestion`/`defaultTips`
// stay defined only because the l10n keys and a few other tests still name them.
//
// Goldens in light and dark. Regenerate with
// `flutter test --update-goldens test/chat/empty_actions_test.dart`.

import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/workspaces_state.dart';
import 'package:dsh_app/ui/chat/chat_screen.dart';
import 'package:dsh_app/ui/chat/empty_actions.dart';
import 'package:dsh_app/ui/chat/empty_state.dart';
import 'package:dsh_app/ui/chat/widgets/whale_tail.dart';
import 'package:dsh_app/ui/theme/app_icons.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _workspace = Workspace(workspaceId: 'w1', path: '/root/workspace/dsh-app', title: 'dsh-app', sessionIds: []);

const _workspaceLabel = '在「dsh-app」中';

/// The new-chat screen: connected in a workspace, or with a failed engine
/// connection.
Future<void> _pumpChat(
  WidgetTester tester, {
  bool failed = false,
  Brightness brightness = Brightness.light,
  Size? size,
  double textScale = 1,
}) async {
  usePhoneView(tester);
  if (size != null) tester.view.physicalSize = size * 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final harness = ChatHarness(connected: !failed);
  final List<Override> overrides = failed
      ? [
          activeConnectionProvider.overrideWithValue(AsyncError<HostConnection?>(StateError('raw'), StackTrace.empty)),
          ...harness.overrides.skip(1),
        ]
      : [...harness.overrides, selectedWorkspaceProvider.overrideWithValue(_workspace)];
  await tester.pumpWidget(testApp(const ChatScreen(), brightness: brightness, overrides: overrides));
  await pumpFrames(tester, 8);
}

/// Just the empty state, centred in a phone-wide page.
Future<void> _pumpState(WidgetTester tester, ChatEmptyState state) async {
  usePhoneView(tester);
  await tester.pumpWidget(testApp(Scaffold(body: Center(child: state))));
  await pumpFrames(tester, 8);
}

double _screenWidth(WidgetTester tester) => tester.view.physicalSize.width / tester.view.devicePixelRatio;

/// The pill around [label] (its ink fills it exactly).
Finder _pill(String label) => find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Rect _rect(WidgetTester tester, String label) => tester.getRect(_pill(label));

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await WhaleSprites.load();
    chatClock = () => DateTime(2026, 10, 23, 15, 20);
  });

  group('geometry', () {
    testWidgets('workspace chip: same height, centred, both sides read equal', (tester) async {
      await _pumpChat(tester);
      final chip = _rect(tester, _workspaceLabel);
      expect(chip.height, moreOrLessEquals(EmptyActions.height));
      expect(chip.center.dx, moreOrLessEquals(_screenWidth(tester) / 2, epsilon: 0.5));
      final folder = tester.getRect(
        find.descendant(of: _pill(_workspaceLabel), matching: find.byIcon(AppIcons.workspace)),
      );
      final chevron = tester.getRect(
        find.descendant(of: _pill(_workspaceLabel), matching: find.byIcon(AppIcons.expand)),
      );
      final left = folder.left - chip.left + EmptyActions.leadingAir;
      final right = chip.right - chevron.right + EmptyActions.chevronAir;
      expect(left, moreOrLessEquals(EmptyActions.inset, epsilon: 0.5));
      expect(right, moreOrLessEquals(EmptyActions.inset, epsilon: 0.5));
      expect(folder.center.dy, moreOrLessEquals(chip.center.dy, epsilon: 0.5));
      expect(chevron.center.dy, moreOrLessEquals(chip.center.dy, epsilon: 0.5));
    });

    testWidgets('no workspace chosen on a remote host: the chip names the one it falls back to', (tester) async {
      usePhoneView(tester);
      final harness = ChatHarness(connected: true);
      await tester.pumpWidget(
        testApp(
          const ChatScreen(),
          overrides: [...harness.overrides, recentWorkspaceForNewChatProvider.overrideWithValue(_workspace)],
        ),
      );
      await pumpFrames(tester, 8);
      expect(find.text(_workspaceLabel), findsOneWidget);
    });

    testWidgets('no workspace at all on a remote host: the chip names its default folder', (tester) async {
      usePhoneView(tester);
      final harness = ChatHarness(connected: true);
      await tester.pumpWidget(
        testApp(
          const ChatScreen(),
          overrides: [...harness.overrides, newChatInHostDefaultProvider.overrideWithValue(true)],
        ),
      );
      await pumpFrames(tester, 8);
      expect(find.text('在「主机默认目录」中'), findsOneWidget);
    });

    testWidgets('the primary pill takes the workspace chip\'s place exactly', (tester) async {
      Future<(Rect, double)> slot(bool failed) async {
        await _pumpState(
          tester,
          ChatEmptyState(
            connected: !failed,
            onSuggestion: (_) {},
            workspace: failed ? null : '项目',
            onWorkspace: () {},
            onReconnect: failed ? () {} : null,
          ),
        );
        final label = failed ? '重新连接' : '在「项目」中';
        // Connected, the title is the line above the slot (no subtitle).
        final subtitle = tester.getRect(find.text(failed ? '没能连上引擎' : '有什么可以帮你？'));
        final pill = _rect(tester, label);
        return (pill, pill.top - subtitle.bottom);
      }

      final (primary, primaryGap) = await slot(true);
      final (chip, chipGap) = await slot(false);
      expect(primary.height, moreOrLessEquals(chip.height));
      expect(primary.height, moreOrLessEquals(EmptyActions.height));
      expect(primary.center.dx, moreOrLessEquals(195, epsilon: 0.5));
      expect(chip.center.dx, moreOrLessEquals(195, epsilon: 0.5));
      expect(primaryGap, moreOrLessEquals(chipGap, epsilon: 0.1));
    });
  });

  group('tiers', () {
    testWidgets('connected: no primary, the workspace chip only', (tester) async {
      await _pumpChat(tester);
      expect(find.byType(EmptyPrimaryPill), findsNothing);
      expect(find.byType(QuietChip), findsOneWidget, reason: 'the workspace chip');
      final theme = Theme.of(tester.element(find.byType(ChatEmptyState)));
      for (final material in tester.widgetList<Material>(
        find.descendant(of: find.byType(QuietChip), matching: find.byType(Material)),
      )) {
        expect(material.color, quietChipFill(theme));
        expect(material.elevation, 0);
      }
    });

    testWidgets('failed: one primary pill, nothing else to tap', (tester) async {
      await _pumpChat(tester, failed: true);
      await pumpFrames(tester, 6);
      expect(find.text('没能连上引擎'), findsOneWidget);
      expect(find.byType(EmptyPrimaryPill), findsOneWidget);
      expect(find.byType(QuietChip), findsNothing);
      final theme = Theme.of(tester.element(find.byType(ChatEmptyState)));
      final fill = tester.widget<Material>(
        find.descendant(of: find.byType(EmptyPrimaryPill), matching: find.byType(Material)),
      );
      expect(fill.color, theme.colorScheme.primary);
    });

    testWidgets('the primary pill reconnects', (tester) async {
      var taps = 0;
      await _pumpState(tester, ChatEmptyState(connected: false, onSuggestion: (_) {}, onReconnect: () => taps++));
      await tester.tap(find.text('重新连接'));
      await tester.pump();
      expect(taps, 1);
      final semantics = tester.getSemantics(_pill('重新连接'));
      expect(semantics.label, '重新连接');
    });

    testWidgets('workspace chip: a label and a hint, not one long sentence', (tester) async {
      var opened = 0;
      await _pumpState(
        tester,
        ChatEmptyState(connected: true, onSuggestion: (_) {}, workspace: '项目', onWorkspace: () => opened++),
      );
      final semantics = tester.getSemantics(_pill('在「项目」中'));
      expect(semantics.label, '在「项目」中');
      expect(semantics.hint, isEmpty);
      await tester.tap(find.text('在「项目」中'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    group('goldens ($mode)', () {
      testWidgets('connected, in a workspace', (tester) async {
        await _pumpChat(tester, brightness: brightness);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/empty_tiers_$mode.png'));
      });

      testWidgets('engine unreachable', (tester) async {
        await _pumpChat(tester, failed: true, brightness: brightness);
        await pumpFrames(tester, 6);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/empty_tiers_failed_$mode.png'));
      });

      testWidgets('360dp, large text', (tester) async {
        await _pumpChat(tester, brightness: brightness, size: const Size(360, 780), textScale: 1.3);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/empty_tiers_narrow_$mode.png'));
      });
    });
  }
}