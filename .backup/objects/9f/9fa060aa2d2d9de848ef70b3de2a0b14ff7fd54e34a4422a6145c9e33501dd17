import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/features/all_features_page.dart' show dshWebOpenerProvider;
import '../ui/features/feature_catalog.dart';

/// A compact, editable view of the same catalog used by 全部功能.
@immutable
class FeatureLayout {
  const FeatureLayout({this.order = const [], this.hidden = const {}, this.compact = true});

  final List<String> order;
  final Set<String> hidden;
  final bool compact;

  List<FeatureItem> resolve(Iterable<FeatureItem> available) {
    final byId = {for (final item in available) item.id: item};
    final result = <FeatureItem>[];
    for (final id in order) {
      final item = byId.remove(id);
      if (item != null && !hidden.contains(id)) result.add(item);
    }
    // New upstream/plugin entries appear automatically instead of disappearing
    // merely because the saved layout predates them.
    result.addAll(byId.values.where((item) => !hidden.contains(item.id)));
    return result;
  }

  FeatureLayout reorder(int oldIndex, int newIndex, List<FeatureItem> visible) {
    if (oldIndex < 0 || oldIndex >= visible.length) return this;
    final ids = resolve(visible).map((item) => item.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    return FeatureLayout(order: ids, hidden: hidden, compact: compact);
  }
}

class FeatureLayoutController extends Notifier<FeatureLayout> {
  static const orderKey = 'conversation.features.order.v1';
  static const hiddenKey = 'conversation.features.hidden.v1';
  static const compactKey = 'conversation.features.compact.v1';
  late Future<void> _loaded;

  @override
  FeatureLayout build() {
    _loaded = _load();
    return const FeatureLayout();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = FeatureLayout(
        order: p.getStringList(orderKey) ?? const [],
        hidden: (p.getStringList(hiddenKey) ?? const []).toSet(),
        compact: p.getBool(compactKey) ?? true,
      );
    } catch (_) {}
  }

  Future<void> _save(FeatureLayout next) async {
    await _loaded;
    if (!ref.mounted) return;
    state = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(orderKey, next.order);
      await p.setStringList(hiddenKey, next.hidden.toList());
      await p.setBool(compactKey, next.compact);
    } catch (_) {}
  }

  Future<void> reorder(int oldIndex, int newIndex, List<FeatureItem> visible) =>
      _save(state.reorder(oldIndex, newIndex, visible));

  Future<void> setHidden(String id, bool hidden) => _save(
    FeatureLayout(
      order: state.order,
      hidden: hidden ? {...state.hidden, id} : ({...state.hidden}..remove(id)),
      compact: state.compact,
    ),
  );

  Future<void> setCompact(bool value) => _save(FeatureLayout(order: state.order, hidden: state.hidden, compact: value));

  Future<void> reset() => _save(const FeatureLayout());
}

final featureLayoutProvider = NotifierProvider<FeatureLayoutController, FeatureLayout>(FeatureLayoutController.new);

/// One opener for 全部功能, settings search, and the conversation shortcuts.
/// Keeping it here prevents three subtly different navigation behaviours.
void openFeature(BuildContext context, WidgetRef ref, FeatureItem item, String? sessionId) {
  if (item.native case final page?) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(sessionId))));
  } else if (item.action case final action?) {
    unawaited(Future.sync(() => action(context, ref, sessionId)));
  } else if (item.webFor(sessionId) case final target?) {
    ref.read(dshWebOpenerProvider)(context, ref, target);
  }
}
