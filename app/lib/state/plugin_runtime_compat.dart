// 第三方插件的「运行时」兼容性诊断（issue #5）。
//
// 和 #3 的 `plugin_compat.dart` 分工不同，别把两者混在一起：
//
//   #3  安装**前**。数据源是市场索引的 `engines.dsh`，一个版本范围比较，
//       结论只有「能不能点安装」。不下载包、不碰 profile。
//   #5  安装**后**。插件已经在 node_modules 里、已经被写进 profile，问题是
//       它能不能在**当前这个** Runtime 上真的注册起来。数据源是插件自己
//       的 package.json / cordis 配置，以及 Runtime 抛出的真实错误。
//
// 这一层只做三件事，且只做判断，不改任何文件：
//   1. 把 Runtime 的原始报错归类成可操作的诊断（哪个插件、哪个字段、怎么办）；
//   2. 在注册前把已知会炸的旧配置认出来，**安全失败**（不静默删字段）；
//   3. 把单个插件的失败圈在它自己身上，别让整列插件跟着红。
//
// 「安全失败」在这里的具体含义：发现不兼容就报错并保留原文，绝不自动改
// 用户配置、绝不放宽工具权限、绝不猜一个等价写法替换上去。唯一的改配置
// 入口是下面显式声明的 `PluginConfigMigration`，由调用方确认后才执行。

import 'dart:convert';

/// One thing wrong with a plugin, narrowed to a kind the UI can act on.
enum PluginRuntimeFault {
  /// The package is not on disk, or its declared entry point is missing.
  missingPackage,

  /// The package exists but `package.json` could not be read or parsed.
  unreadableManifest,

  /// The plugin was built against an older Host API than this runtime exposes.
  hostApiMismatch,

  /// A configuration field the current runtime no longer accepts
  /// (`toolFilter`, `persona`, …). Always a hard stop: the runtime throws.
  removedConfigField,

  /// An Agent Preset referenced by the plugin is gone or never mounted.
  missingAgentPreset,

  /// A plugin id in the composition cannot be resolved.
  unresolvedPluginReference,

  /// The plugin threw while registering. Whatever it was, it is the plugin's.
  registrationFailed,

  /// Nothing declared and nothing failed — we simply do not know.
  unverified,
}

/// A single diagnostic row: what, where, and what to do about it.
///
/// [plugin] is the package that owns the fault (null when the runtime could not
/// tell us). [path] is the configuration path when the fault is field-level,
/// e.g. `dsh.profile.bundles[3].config.toolFilter`.
class PluginRuntimeDiagnostic {
  const PluginRuntimeDiagnostic({
    required this.plugin,
    required this.fault,
    required this.message,
    this.path,
    this.runtimeVersion,
    this.pluginVersion,
    this.rawError,
  });

  /// The owning package name, `@scope/name`. Null when unattributable.
  final String? plugin;
  final PluginRuntimeFault fault;

  /// One line a person can read. Keeps the runtime's own wording where it had
  /// any, so nobody has to guess what "failed" meant.
  final String message;

  /// Field path inside the profile manifest, when the fault is field-level.
  final String? path;

  final String? runtimeVersion;
  final String? pluginVersion;

  /// The runtime's original error text, verbatim. Kept for the diagnosis log
  /// and for a bug report; never shown as the headline.
  final String? rawError;

  /// Whether this fault means the plugin cannot run. `unverified` is the only
  /// non-blocking kind: we do not know, so we do not pretend either way.
  bool get blocksPlugin => fault != PluginRuntimeFault.unverified;

  /// Whether the fault belongs to a field this runtime removed. These are the
  /// ones a migration could ever touch — and only with explicit consent.
  bool get isRemovedField => fault == PluginRuntimeFault.removedConfigField;

  @override
  String toString() =>
      'PluginRuntimeDiagnostic(${plugin ?? '?'}, ${fault.name}'
      '${path == null ? '' : ', $path'}, $message)';
}

/// Fields the current DSH runtime rejects outright.
///
/// Kept as data, not as branches, so adding the next removal is one line and
/// the tests can walk it. Source of truth is the runtime itself: these strings
/// are copied from the `throw` sites in `@deepseek-ai/*`, with a test that
/// fails when the runtime disagrees (see `plugin_runtime_compat_test.dart`).
class RemovedPluginFields {
  const RemovedPluginFields({
    required this.field,
    required this.plugin,
    required this.replacement,
  });

  /// The key, as it appears in the config object.
  final String field;

  /// The runtime package that rejects it, `dsh-tool-subagent` and friends.
  final String plugin;

  /// What the runtime tells people to use instead. Empty when it says nothing.
  final String replacement;

  static const all = <RemovedPluginFields>[
    RemovedPluginFields(
      field: 'toolFilter',
      plugin: 'dsh-tool-subagent',
      replacement: 'configure tool plugins in an Agent Preset and select it with agentPreset',
    ),
    RemovedPluginFields(
      field: 'persona',
      plugin: 'dsh-tool-subagent',
      replacement: 'configure persona in an Agent Preset and select it with agentPreset',
    ),
  ];

  static RemovedPluginFields? forField(String name) {
    for (final entry in all) {
      if (entry.field == name) return entry;
    }
    return null;
  }
}

/// What a plugin says about itself, read from its `package.json`.
///
/// Everything here is optional on purpose: a plugin that declares nothing is
/// [unverified], never "incompatible". Guessing either way is how a working
/// plugin gets blocked or a broken one gets blessed.
class PluginCompatibilityDeclaration {
  const PluginCompatibilityDeclaration({
    required this.name,
    this.version,
    this.dshRange,
    this.nodeRange,
    this.hostApiRange,
    this.configSchemaVersion,
    this.requiresPlugins = const [],
    this.usesExperimentalApi = false,
  });

  final String name;
  final String? version;
  final String? dshRange;
  final String? nodeRange;
  final String? hostApiRange;
  final String? configSchemaVersion;

  /// Plugin ids the composition must also provide for this one to start.
  final List<String> requiresPlugins;
  final bool usesExperimentalApi;

  /// Nothing at all declared: an older plugin that predates the convention.
  bool get declaresNothing =>
      dshRange == null &&
      nodeRange == null &&
      hostApiRange == null &&
      configSchemaVersion == null &&
      requiresPlugins.isEmpty;

  /// Reads a plugin's own declaration out of its `package.json` text.
  ///
  /// Returns null when the text is not a JSON object — the caller reports that
  /// as [PluginRuntimeFault.unreadableManifest] rather than guessing.
  static PluginCompatibilityDeclaration? fromManifestJson(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final name = decoded['name'];
    if (name is! String || name.isEmpty) return null;
    final dsh = decoded['dsh'];
    final dshMap = dsh is Map<String, Object?> ? dsh : const <String, Object?>{};
    final engines = decoded['engines'];
    final enginesMap = engines is Map<String, Object?> ? engines : const <String, Object?>{};
    // The compatibility block lives under `dsh.compatibility` when a plugin
    // ships one; older plugins only have `engines`.
    final compat = dshMap['compatibility'];
    final compatMap = compat is Map<String, Object?> ? compat : const <String, Object?>{};
    final requires = compatMap['requiresPlugins'];
    return PluginCompatibilityDeclaration(
      name: name,
      version: decoded['version'] is String ? decoded['version'] as String : null,
      dshRange: _string(compatMap['dsh']) ?? _string(enginesMap['dsh']),
      nodeRange: _string(compatMap['node']) ?? _string(enginesMap['node']),
      hostApiRange: _string(compatMap['hostApi']),
      configSchemaVersion: _string(compatMap['configSchema']),
      requiresPlugins: requires is List ? [for (final e in requires) if (e is String) e] : const [],
      usesExperimentalApi: compatMap['experimental'] == true,
    );
  }

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;
}

/// The outcome of looking at one plugin before it is registered.
class PluginRuntimeCheck {
  const PluginRuntimeCheck({required this.plugin, required this.diagnostics});

  final String plugin;
  final List<PluginRuntimeDiagnostic> diagnostics;

  /// Nothing blocks it: either everything checked out, or the only thing we
  /// have is an `unverified` row.
  bool get canRegister => diagnostics.every((d) => !d.blocksPlugin);
  bool get isUnverified => diagnostics.any((d) => d.fault == PluginRuntimeFault.unverified);
  List<PluginRuntimeDiagnostic> get blockers =>
      [for (final d in diagnostics) if (d.blocksPlugin) d];
}

/// Turn a runtime error into a diagnostic, or null when nothing matches.
///
/// This is the piece that makes the red text useful. The runtime throws bare
/// `Error`s with the field buried in a sentence; here that becomes "which
/// plugin, which field, what replaces it", and the original text is kept.
PluginRuntimeDiagnostic? classifyPluginRuntimeError(
  Object error, {
  required String plugin,
  String? pluginVersion,
  String? runtimeVersion,
  String? path,
}) {
  final text = error is Error ? error.toString() : error.toString();
  // `tool-subagent: toolFilter is no longer supported; configure ... in an
  // Agent Preset and select it with agentPreset (spawn only)`
  for (final removed in RemovedPluginFields.all) {
    if (!text.contains('$removed.field is no longer supported')) continue;
    return PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.removedConfigField,
      message: '${plugin} 用了 ${removed.plugin} 已经移除的配置项 ${removed.field}。'
          '当前运行时会直接拒绝启动；请把这项配置改成 ${removed.replacement}。',
      path: path,
      pluginVersion: pluginVersion,
      runtimeVersion: runtimeVersion,
      rawError: text,
    );
  }
  // `tool-subagent-list-agents: never started`
  if (text.contains('never started')) {
    return PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.missingAgentPreset,
      message: '$plugin 引用的 Agent Preset 没有启动。请确认预设还在、id 没改，再重试。',
      path: path,
      pluginVersion: pluginVersion,
      runtimeVersion: runtimeVersion,
      rawError: text,
    );
  }
  if (text.contains('Cannot find module') || text.contains('ERR_MODULE_NOT_FOUND')) {
    return PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.missingPackage,
      message: '$plugin 的入口文件找不到。装包可能没装全，重装一次这个插件。',
      path: path,
      pluginVersion: pluginVersion,
      runtimeVersion: runtimeVersion,
      rawError: text,
    );
  }
  return null;
}

/// Check a plugin against the runtime it is about to be registered on.
///
/// [manifestJson] is the plugin's `package.json` text, or null when the file is
/// not there. [config] is the plugin's configuration object from the profile,
/// or null when it has none. [providedPlugins] is the set of plugin ids the
/// composition can resolve; pass null when the caller did not collect them, so
/// an absent id is not reported as a fault we cannot prove.
PluginRuntimeCheck checkPluginAtRuntime({
  required String plugin,
  required String? manifestJson,
  required String? runtimeDshVersion,
  Map<String, Object?>? config,
  Set<String>? providedPlugins,
}) {
  final diagnostics = <PluginRuntimeDiagnostic>[];
  if (manifestJson == null) {
    diagnostics.add(PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.missingPackage,
      message: '$plugin 不在 node_modules 里。可能装到一半失败了，重装一次。',
      runtimeVersion: runtimeDshVersion,
    ));
    return PluginRuntimeCheck(plugin: plugin, diagnostics: diagnostics);
  }
  final declaration = PluginCompatibilityDeclaration.fromManifestJson(manifestJson);
  if (declaration == null) {
    diagnostics.add(PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.unreadableManifest,
      message: '$plugin 的 package.json 读不出来（不是合法 JSON，或没有 name）。'
          '这个包可能是坏的，也可能是别的工具写坏的。',
      runtimeVersion: runtimeDshVersion,
    ));
    return PluginRuntimeCheck(plugin: plugin, diagnostics: diagnostics);
  }
  // Removed fields first: these are a guaranteed throw, so they outrank a
  // version range that merely might not match.
  final cfg = config;
  if (cfg != null) {
    for (final entry in RemovedPluginFields.all) {
      if (!cfg.containsKey(entry.field)) continue;
      diagnostics.add(PluginRuntimeDiagnostic(
        plugin: plugin,
        fault: PluginRuntimeFault.removedConfigField,
        message: '$plugin 的配置里有 ${entry.field}，${entry.plugin} 已经不再接受它。'
            '删掉这项并${entry.replacement}，否则插件启动时会被拒绝。',
        path: 'config.${entry.field}',
        pluginVersion: declaration.version,
        runtimeVersion: runtimeDshVersion,
      ));
    }
  }
  // A composition that names a plugin nobody provides: the whole entry stays
  // dark with no explanation unless we say which id is missing.
  final provided = providedPlugins;
  if (provided != null) {
    for (final required in declaration.requiresPlugins) {
      if (provided.contains(required)) continue;
      diagnostics.add(PluginRuntimeDiagnostic(
        plugin: plugin,
        fault: PluginRuntimeFault.unresolvedPluginReference,
        message: '$plugin 需要 $required，但这次 composition 里没有它。装上前置插件，或换个不带这个依赖的版本。',
        pluginVersion: declaration.version,
        runtimeVersion: runtimeDshVersion,
      ));
    }
  }
  if (diagnostics.isNotEmpty) return PluginRuntimeCheck(plugin: plugin, diagnostics: diagnostics);
  // Nothing declared and nothing removed: we genuinely do not know.
  if (declaration.declaresNothing) {
    diagnostics.add(PluginRuntimeDiagnostic(
      plugin: plugin,
      fault: PluginRuntimeFault.unverified,
      message: '$plugin 没有声明兼容范围，无法在注册前验证。装上后如果起不来，会在这里给出具体原因。',
      pluginVersion: declaration.version,
      runtimeVersion: runtimeDshVersion,
    ));
  }
  return PluginRuntimeCheck(plugin: plugin, diagnostics: diagnostics);
}

/// A configuration migration a person has to ask for.
///
/// The issue is explicit that migration must be bounded: only a known old
/// shape, only an exactly matching target, always with a snapshot and a diff.
/// This type is that contract — nothing in this file applies one by itself.
class PluginConfigMigration {
  const PluginConfigMigration({
    required this.id,
    required this.plugin,
    required this.fromField,
    required this.toField,
    required this.explain,
  });

  /// Stable id so a migration is applied at most once per config.
  final String id;

  /// The runtime package whose config this rewrites (`dsh-tool-subagent`).
  final String plugin;

  /// The field that has to go.
  final String fromField;

  /// The field that replaces it. Empty when the runtime wants it in a preset
  /// instead, which is not something we can rewrite for the user.
  final String toField;

  /// One line for the confirmation sheet.
  final String explain;

  /// Rewrites [config] if and only if it has exactly the shape this migration
  /// knows: [fromField] present, [toField] absent, nothing else touched.
  ///
  /// Returns null when it does not apply, so a caller never has to guess
  /// whether "no change" meant "nothing to do" or "changed nothing".
  Map<String, Object?>? apply(Map<String, Object?> config) {
    if (!config.containsKey(fromField)) return null;
    if (toField.isNotEmpty && config.containsKey(toField)) return null;
    final next = Map<String, Object?>.from(config)..remove(fromField);
    if (toField.isEmpty) return next;
    next[toField] = config[fromField];
    return next;
  }
}

/// Which migrations apply to a config. Data, so the sheet can list them.
List<PluginConfigMigration> migrationsFor(Map<String, Object?> config) => [
  for (final migration in _migrations)
    if (migration.apply(config) != null) migration,
];

/// The migrations we are willing to offer. Each one is a *known* old shape with
/// a *documented* replacement; a field we merely suspect is old is not here.
///
/// `toolFilter` / `persona` deliberately have no entry: the runtime says to move
/// them into an Agent Preset, and moving a tool allow-list into a preset is a
/// semantic change we must not perform on someone's behalf. They surface as
/// [PluginRuntimeFault.removedConfigField] with instructions instead.
const _migrations = <PluginConfigMigration>[
  PluginConfigMigration(
    id: 'subagent-agent-preset',
    plugin: 'dsh-tool-subagent',
    fromField: 'preset',
    toField: 'agentPreset',
    explain: '把旧字段 preset 改名为 agentPreset（DSH 在 0.2 之后改了名，语义不变）。',
  ),
];
