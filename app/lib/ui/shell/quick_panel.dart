// 快捷入口: the panel a left swipe over the chat pulls in from the right, the
// sessions drawer's mirror. It lists destinations the drawer already has and
// opens them the way the drawer does; what each page requires stays with the
// page. Which ones and in what order: 设置 › 界面 (quick_panel_items_sheet.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/quick_panel_state.dart';
import '../chat/control_icons.dart';
import '../session/conversation_panel.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'drawer/drawer_destination.dart';

/// A destination's glyph as a row draws it.
///
/// 自动化任务 uses ChatGPT's own vector mark (`ChatGptScheduledTaskIcon`) so
/// the three feature rows read as one family; the rest keep the app's material
/// glyphs. One widget, so the drawer, 快捷入口 and 设置 › 界面 draw the same
/// thing at the same size.
class DrawerDestinationGlyph extends StatelessWidget {
  const DrawerDestinationGlyph({super.key, required this.destination, this.size = 20});

  final DrawerDestination destination;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (destination == DrawerDestination.schedules) {
      return ChatGptScheduledTaskIcon(size: size, color: IconTheme.of(context).color);
    }
    return Icon(destination.icon, size: size, color: IconTheme.of(context).color);
  }
}

/// A destination as 快捷入口 and its settings show it, by the name and the
/// glyph its other ways in use.
extension DrawerDestinationLook on DrawerDestination {
  IconData get icon => switch (this) {
    DrawerDestination.web => AppIcons.webApp,
    DrawerDestination.remote => AppIcons.remoteHosts,
    DrawerDestination.plugins => AppIcons.plugin,
    DrawerDestination.engine => AppIcons.engine,
    DrawerDestination.settings => AppIcons.settings,
    DrawerDestination.settingsSearch => AppIcons.search,
    DrawerDestination.features => AppIcons.allFeatures,
    // The automation row in the drawer draws the ChatGPT vector glyph
    // (see [_DrawerDestinationGlyph]); everywhere else the app's own
    // calendar glyph is the one this destination has always used.
    DrawerDestination.schedules => AppIcons.automation,
  };

  String label(L10n l10n) => switch (this) {
    DrawerDestination.web => l10n.commonWeb,
    DrawerDestination.remote => l10n.commonRemoteHost,
    DrawerDestination.plugins => l10n.hubPlugins,
    DrawerDestination.engine => l10n.hubSettingsEngine,
    DrawerDestination.settings => l10n.commonSettings,
    DrawerDestination.settingsSearch => l10n.searchSettingsHint,
    DrawerDestination.features => l10n.hubSettingsAllFeatures,
    DrawerDestination.schedules => l10n.featuresSchedules,
  };
}

class QuickPanel extends ConsumerWidget {
  const QuickPanel({super.key, required this.motion, required this.onOpen, this.sessionId});

  /// The conversation open behind it: the panel is about that one, the shortcuts become
  /// its foot. Null: just the shortcuts.
  final String? sessionId;

  /// The panel's 0 → 1 animation, for its glass ([SlidingGlass]).
  final Animation<double> motion;
  final ValueChanged<DrawerDestination> onOpen;

  /// Short labels need less than the drawer's 320.
  static const width = 260.0;

  /// With a conversation, as wide as what it shows wants: its panes are the page's tabs.
  static const conversationWidth = 360.0;

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(AppShape.xl),
    bottomLeft: Radius.circular(AppShape.xl),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(quickPanelProvider.select((p) => p.items));
    final content = Material(
      type: MaterialType.transparency,
      child: SafeArea(
        left: false,
        child: switch (sessionId) {
          final sessionId? => ConversationPanel(sessionId: sessionId, onOpen: onOpen),
          null => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.shellQuickPanel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (final destination in items) QuickPanelRow(destination: destination, onTap: () => onOpen(destination)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 13),
                child: Text(
                  l10n.shellQuickPanelHint('${l10n.commonSettings} › ${l10n.hubSettingsInterface}'),
                  style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
                ),
              ),
            ],
          ),
        },
      ),
    );
    return SlidingGlass(motion: motion, tier: GlassTier.sheet, borderRadius: _radius, child: content);
  }
}

/// A row on the drawer's grid: the highlight's edge at 10, the glyph at 20.
class QuickPanelRow extends StatelessWidget {
  const QuickPanelRow({super.key, required this.destination, required this.onTap});

  final DrawerDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = destination.label(context.l10n);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('quick-panel-${destination.name}'),
        onTap: onTap,
        customBorder: Squircle.border(AppShape.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                DrawerDestinationGlyph(destination: destination, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
