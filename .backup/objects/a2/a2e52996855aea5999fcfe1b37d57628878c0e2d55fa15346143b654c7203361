import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/scene_accounts_state.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';

/// Local scene profiles, deliberately separate from DeepSeek cloud sign-in.
class SceneAccountsPage extends ConsumerWidget {
  const SceneAccountsPage({super.key});

  Future<void> _name(BuildContext context, WidgetRef ref, {SceneAccount? account}) async {
    final controller = TextEditingController(text: account?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? appL10n.sceneCreate : appL10n.commonRename),
        content: TextField(controller: controller, autofocus: true, maxLength: 32),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(appL10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(appL10n.commonSave)),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final controllerState = ref.read(sceneAccountsProvider.notifier);
    if (account == null) {
      await controllerState.create(name);
    } else {
      await controllerState.rename(account.id, name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SceneAccount account) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(appL10n.sceneDeleteConfirm(account.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(appL10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(appL10n.commonDelete)),
        ],
      ),
    );
    if (yes == true) await ref.read(sceneAccountsProvider.notifier).remove(account.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sceneAccountsProvider);
    return AppPage.list(
      title: appL10n.sceneAccounts,
      subtitle: Text(appL10n.sceneAccountsHint),
      children: [
        for (final account in state.accounts)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
            child: ListTile(
              leading: CircleAvatar(child: Text(account.name.characters.first)),
              title: Text(account.name),
              subtitle: Text(account.admin ? appL10n.sceneAdmin : appL10n.sceneConfigOnly),
              selected: account.id == state.currentId,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: appL10n.commonRename, icon: const Icon(AppIcons.edit), onPressed: () => _name(context, ref, account: account)),
                  if (!account.admin)
                    IconButton(tooltip: appL10n.commonDelete, icon: const Icon(AppIcons.delete), onPressed: () => _delete(context, ref, account)),
                ],
              ),
              onTap: account.id == state.currentId ? null : () => unawaited(ref.read(sceneAccountsProvider.notifier).select(account.id)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _name(context, ref),
            icon: const Icon(AppIcons.add),
            label: Text(appL10n.sceneCreate),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(appL10n.sceneIsolationNotice, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}