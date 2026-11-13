// Purge plugin state: one provider per read, all invalidated after an action.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purge_api.dart';

final purgeStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.status();
});

final purgeOverrideProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.override();
});

final purgeRulesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.rules('status');
});

final purgeSkillsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.skills('status');
});

final purgeDrillProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.drillGrant();
});

final purgeUpdateProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(purgeApiProvider);
  if (api == null) throw StateError('引擎未连接');
  return api.update('check');
});
