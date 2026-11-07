import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/feature_layout_state.dart';
import '../../state/sessions_state.dart';
import '../features/feature_catalog.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// Every catalog entry on 信息, in an editable grid. The catalog remains the
/// single source of truth: entries added by upstream or plugin panels appear
/// here without another list to maintain.
class ConversationFeatureGrid extends ConsumerStatefulWidget {
  const ConversationFeatureGrid({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ConversationFeatureGrid> createState() => _ConversationFeatureGridState();
}

class _ConversationFeatureGridState extends ConsumerState<ConversationFeatureGrid> {
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(featureSectionsProvider);
    final available = sections.expand((section) => section.items).toList();
    final layout = ref.watch(featureLayoutProvider);
    final items = layout.resolve(available);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  appL10n.catalogAllFeatures,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (editing)
                IconButton(
                  tooltip: appL10n.commonReset,
                  onPressed: () => ref.read(featureLayoutProvider.notifier).reset(),
                  icon: const Icon(AppIcons.regenerate, size: 19),
                ),
              TextButton.icon(
                key: const ValueKey('edit-feature-layout'),
                onPressed: () => setState(() => editing = !editing),
                icon: Icon(editing ? AppIcons.checkboxOn : AppIcons.edit, size: 17),
                label: Text(editing ? appL10n.commonDone : appL10n.commonEdit),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(appL10n.commonNone, style: TextStyle(color: scheme.onSurfaceVariant)),
          )
        else
          GridView.builder(
            // This grid lives inside ConversationOverview's ListView. It must
            // never own a second scroll controller or rebuild with the chat.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.compact ? 3 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: layout.compact ? 1.15 : 1.55,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FeatureShortcut(
                key: ValueKey('conversation-feature-${item.id}'),
                item: item,
                index: index,
                count: items.length,
                editing: editing,
                compact: layout.compact,
                enabled: !item.needsSession || widget.sessionId.isNotEmpty,
                onOpen: () {
                  if (editing) return;
                  openFeature(context, ref, item, ref.read(currentSessionProvider) ?? widget.sessionId);
                },
                onMove: (delta) {
                  final target = index + delta;
                  if (target >= 0 && target < items.length) {
                    ref.read(featureLayoutProvider.notifier).reorder(index, target, items);
                  }
                },
                onHide: () => ref.read(featureLayoutProvider.notifier).setHidden(item.id, true),
              );
            },
          ),
        if (editing) ...[
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(appL10n.commonCompact),
            value: layout.compact,
            onChanged: ref.read(featureLayoutProvider.notifier).setCompact,
          ),
          for (final item in available.where((item) => layout.hidden.contains(item.id)))
            ListTile(
              dense: true,
              leading: Icon(item.icon, size: 19),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: appL10n.commonRestore,
                icon: const Icon(AppIcons.add, size: 20),
                onPressed: () => ref.read(featureLayoutProvider.notifier).setHidden(item.id, false),
              ),
            ),
        ],
      ],
    );
  }
}

class _FeatureShortcut extends StatelessWidget {
  const _FeatureShortcut({
    super.key,
    required this.item,
    required this.index,
    required this.count,
    required this.editing,
    required this.compact,
    required this.enabled,
    required this.onOpen,
    required this.onMove,
    required this.onHide,
  });

  final FeatureItem item;
  final int index;
  final int count;
  final bool editing;
  final bool compact;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.045),
      shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled || editing ? onOpen : null,
        onLongPress: onHide,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: compact ? 23 : 26, color: foreground),
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
            if (editing) ...[
              Positioned(
                right: 0,
                top: 0,
                child: _EditKey(icon: AppIcons.close, onTap: onHide),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: _EditKey(icon: AppIcons.back, onTap: index == 0 ? null : () => onMove(-1)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _EditKey(icon: AppIcons.forward, onTap: index == count - 1 ? null : () => onMove(1)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditKey extends StatelessWidget {
  const _EditKey({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    iconSize: 16,
    onPressed: onTap,
    icon: Icon(icon),
  );
}