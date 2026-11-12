// The quick-access row above the chat title: three dots collapsed, three
// capsules expanded (Terminal / Team / Files). Replaces the old separate
// WorkProgressKey and HeaderAgentsKey entries.
//
// The component owns only its expanded state and hit targets. Routes are
// injected by ChatScreen so the header never needs a session id or a
// Riverpod ref of its own.

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/theme.dart';

/// Stable keys for widget tests and golden names.
abstract final class QuickAccessKeys {
  static const root = ValueKey('chat-quick-access');
  static const open = ValueKey('chat-quick-access-open');
  static const close = ValueKey('chat-quick-access-close');
  static const collapsed = ValueKey('chat-quick-access-collapsed');
  static const expanded = ValueKey('chat-quick-access-expanded');
  static const terminal = ValueKey('chat-quick-access-terminal');
  static const team = ValueKey('chat-quick-access-team');
  static const files = ValueKey('chat-quick-access-files');
}

/// A new chat has no session, so all three actions are visible but disabled.
/// No session is created automatically: tapping must not fire a route or an RPC.
class QuickAccessRow extends StatefulWidget {
  const QuickAccessRow({
    super.key,
    required this.enabled,
    required this.onTerminal,
    required this.onTeam,
    required this.onFiles,
    this.disabledHint,
  });

  final bool enabled;
  final VoidCallback onTerminal;
  final VoidCallback onTeam;
  final VoidCallback onFiles;

  /// Read by a screen reader on each capsule when the row is disabled.
  final String? disabledHint;

  /// The row's own height. [ChatHeader.heightOf] adds it to the top inset.
  static const height = 36.0;

  @override
  State<QuickAccessRow> createState() => _QuickAccessRowState();
}

class _QuickAccessRowState extends State<QuickAccessRow> {
  // Always collapsed after a process restart: the user never asked to persist
  // an open menu across sessions.
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = ChatGptShellColors.of(context);
    final quick = AppMotion.of(context, AppMotion.quick);
    final enabled = widget.enabled;

    Widget dot() => Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: enabled ? shell.primaryText : shell.tertiaryText,
            shape: BoxShape.circle,
          ),
        );

    Widget capsule({
      required ValueKey key,
      required String label,
      required VoidCallback onTap,
    }) {
      final face = Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? shell.rowSelected : shell.divider,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: shell.divider, width: 0.5),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            color: enabled ? shell.primaryText : shell.tertiaryText,
          ),
        ),
      );
      return Semantics(
        key: key,
        button: true,
        enabled: enabled,
        label: enabled ? label : (widget.disabledHint ?? label),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(opacity: enabled ? 1 : 0.55, child: face),
        ),
      );
    }

    Widget dots() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Semantics(
            key: QuickAccessKeys.open,
            button: true,
            label: '${l10n.botsTerminal}, ${l10n.botsAgentTeam}, ${l10n.botsFiles}',
            excludeSemantics: true,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    dot(),
                  ],
                ],
              ),
            ),
          ),
        );

    Widget close() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Semantics(
            key: QuickAccessKeys.close,
            button: true,
            label: l10n.commonClose,
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 30,
              child: Icon(Icons.close, size: 16, color: shell.secondaryText),
            ),
          ),
        );

    // Both states occupy [QuickAccessRow.height], so the chat list never jumps.
    // scaleDown keeps the expanded capsules inside a 320dp / large-text
    // viewport: a bare Row under Center gets loose constraints and would
    // overflow instead of letting the labels ellipsize.
    return SizedBox(
      key: QuickAccessKeys.root,
      height: QuickAccessRow.height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedSwitcher(
            duration: quick,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: !_expanded
                ? KeyedSubtree(key: QuickAccessKeys.collapsed, child: dots())
                : KeyedSubtree(
                    key: QuickAccessKeys.expanded,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        capsule(key: QuickAccessKeys.terminal, label: l10n.botsTerminal, onTap: widget.onTerminal),
                        const SizedBox(width: 6),
                        capsule(key: QuickAccessKeys.team, label: l10n.botsAgentTeam, onTap: widget.onTeam),
                        const SizedBox(width: 6),
                        capsule(key: QuickAccessKeys.files, label: l10n.botsFiles, onTap: widget.onFiles),
                        const SizedBox(width: 6),
                        close(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}