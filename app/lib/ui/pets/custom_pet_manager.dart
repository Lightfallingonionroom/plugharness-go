import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../../pets/custom_pets.dart';
import '../../pets/pet_prefs.dart';
import '../../pets/pet_signals.dart';
import '../theme/app_icons.dart';

/// Add, name and delete user pets. Imported images are stored privately and
/// turned into a normal pack, so chat, overlay and notification art all work.
class CustomPetManager extends ConsumerStatefulWidget {
  const CustomPetManager({super.key});

  @override
  ConsumerState<CustomPetManager> createState() => _CustomPetManagerState();
}

class _CustomPetManagerState extends ConsumerState<CustomPetManager> {
  bool busy = false;

  Future<void> add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: appL10n.botsPetCustom);
        return AlertDialog(
          title: Text(appL10n.botsPetCustomName),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 32,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(appL10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(appL10n.commonAdd)),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    setState(() => busy = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048);
      if (picked == null) return;
      final pack = await ref.read(customPetStoreProvider).importImage(await picked.readAsBytes(), name);
      ref.invalidate(customPetPacksProvider);
      ref.invalidate(petPackProvider(pack.id));
      await ref.read(petPrefsProvider.notifier).setPack(pack.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appL10n.botsPetImportFailed)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addPack() async {
    setState(() => busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      final file = files.singleOrNull;
      if (file == null) return;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > 32 * 1024 * 1024) throw const FormatException('archive size');
        bytes.add(chunk);
      }
      final pack = await ref.read(customPetStoreProvider).importArchive(bytes.takeBytes());
      ref.invalidate(customPetPacksProvider);
      ref.invalidate(petPackProvider(pack.id));
      await ref.read(petPrefsProvider.notifier).setPack(pack.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appL10n.botsPetPackImportFailed)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(appL10n.botsPetDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(appL10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(appL10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (ref.read(petPrefsProvider).packId == id) await ref.read(petPrefsProvider.notifier).setPack(defaultPetId);
    await ref.read(customPetStoreProvider).delete(id);
    ref.invalidate(customPetPacksProvider);
    ref.invalidate(petPackProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    final custom = ref.watch(customPetPacksProvider).value ?? const [];
    return Column(
      children: [
        ListTile(
          leading: busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(AppIcons.addImage),
          title: Text(appL10n.botsPetAddImage),
          subtitle: Text(appL10n.botsPetAddImageHint),
          onTap: busy ? null : add,
        ),
        ListTile(
          leading: const Icon(AppIcons.add),
          title: Text(appL10n.botsPetAddPack),
          subtitle: Text(appL10n.botsPetAddPackHint),
          onTap: busy ? null : addPack,
        ),
        for (final pack in custom)
          ListTile(
            key: ValueKey('custom-pet-${pack.id}'),
            leading: const Icon(AppIcons.pet),
            title: Text(pack.name),
            subtitle: Text(appL10n.botsPetCustom),
            trailing: IconButton(
              tooltip: appL10n.commonDelete,
              icon: const Icon(AppIcons.delete),
              onPressed: () => unawaited(remove(pack.id)),
            ),
            onTap: () => ref.read(petPrefsProvider.notifier).setPack(pack.id),
          ),
      ],
    );
  }
}