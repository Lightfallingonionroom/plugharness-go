// issue #5: 第三方插件运行时兼容性诊断的契约测试。
//
// 这些测试钉的是「判断」而不是「界面」：遇到什么错误归成哪一类、什么情况
// 必须拦住、什么情况只能说「不知道」。界面照着这些结论画就行。
//
// 用的是纯 Dart（只 import dart:convert），所以本地 `dart test` 就能跑。

import 'dart:convert';

import 'package:dsh_app/state/plugin_runtime_compat.dart';
import 'package:flutter_test/flutter_test.dart';

String manifest(Map<String, Object?> overrides) => jsonEncode({
      'name': '@someone/plugin',
      'version': '1.2.3',
      ...overrides,
    });

void main() {
  group('manifest parsing', () {
    test('reads engines.dsh and engines.node from an older-style package', () {
      final d = PluginCompatibilityDeclaration.fromManifestJson(manifest({
        'engines': {'dsh': '>=0.1.0 <0.3.0', 'node': '>=20'},
      }))!;
      expect(d.name, '@someone/plugin');
      expect(d.version, '1.2.3');
      expect(d.dshRange, '>=0.1.0 <0.3.0');
      expect(d.nodeRange, '>=20');
      expect(d.declaresNothing, isFalse);
    });

    test('reads the dsh.compatibility block and lets it win over engines', () {
      final d = PluginCompatibilityDeclaration.fromManifestJson(manifest({
        'engines': {'dsh': '>=0.1.0'},
        'dsh': {
          'compatibility': {
            'dsh': '>=0.2.0-rc.2',
            'hostApi': '2',
            'configSchema': '3',
            'requiresPlugins': ['dsh-tool-subagent', 7, 'dsh-agent-presets'],
            'experimental': true,
          },
        },
      }))!;
      expect(d.dshRange, '>=0.2.0-rc.2');
      expect(d.hostApiRange, '2');
      expect(d.configSchemaVersion, '3');
      // Non-strings are dropped rather than stringified.
      expect(d.requiresPlugins, ['dsh-tool-subagent', 'dsh-agent-presets']);
      expect(d.usesExperimentalApi, isTrue);
    });

    test('a plugin that declares nothing is unknown, never "incompatible"', () {
      final d = PluginCompatibilityDeclaration.fromManifestJson(manifest({}))!;
      expect(d.declaresNothing, isTrue);
    });

    test('broken JSON returns null instead of a half-read declaration', () {
      expect(PluginCompatibilityDeclaration.fromManifestJson('{not json'), isNull);
      expect(PluginCompatibilityDeclaration.fromManifestJson('[]'), isNull);
      expect(PluginCompatibilityDeclaration.fromManifestJson('{"version":"1.0.0"}'), isNull);
    });
  });

  group('removed fields', () {
    test('toolFilter and persona are the two the runtime throws on', () {
      expect(RemovedPluginFields.forField('toolFilter')!.plugin, 'dsh-tool-subagent');
      expect(RemovedPluginFields.forField('persona')!.plugin, 'dsh-tool-subagent');
      expect(RemovedPluginFields.forField('agentPreset'), isNull);
    });

    test('a config carrying toolFilter is blocked before it is registered', () {
      final check = checkPluginAtRuntime(
        plugin: '@someone/plugin',
        manifestJson: manifest({}),
        runtimeDshVersion: '0.2.0-rc.2',
        config: {'toolFilter': ['read', 'write']},
      );
      expect(check.canRegister, isFalse);
      final fault = check.blockers.single;
      expect(fault.fault, PluginRuntimeFault.removedConfigField);
      expect(fault.path, 'config.toolFilter');
      // The message has to name the field and the way out, or it is just noise.
      expect(fault.message, contains('toolFilter'));
      expect(fault.message, contains('Agent Preset'));
    });

    test('persona is blocked the same way', () {
      final check = checkPluginAtRuntime(
        plugin: '@someone/plugin',
        manifestJson: manifest({}),
        runtimeDshVersion: '0.2.0-rc.2',
        config: {'persona': 'reviewer'},
      );
      expect(check.blockers.single.fault, PluginRuntimeFault.removedConfigField);
      expect(check.blockers.single.path, 'config.persona');
    });

    test('a clean config passes', () {
      final check = checkPluginAtRuntime(
        plugin: '@someone/plugin',
        manifestJson: manifest({
          'engines': {'dsh': '>=0.1.0'},
        }),
        runtimeDshVersion: '0.2.0-rc.2',
        config: {'maxDepth': 2},
      );
      expect(check.canRegister, isTrue);
      expect(check.isUnverified, isFalse);
    });
  });

  group('error classification', () {
    test('the real toolFilter throw from dsh-tool-subagent', () {
      // Copied from node_modules/@deepseek-ai/dsh-tool-subagent/lib/index.js.
      const thrown =
          'Error: tool-subagent: toolFilter is no longer supported; configure '
          'persona and tool plugins in an Agent Preset and select it with '
          'agentPreset (spawn only)';
      final d = classifyPluginRuntimeError(
        thrown,
        plugin: 'mmparko/dsh-purge',
        pluginVersion: '0.3.0',
        runtimeVersion: '0.2.0-rc.2',
      )!;
      expect(d.fault, PluginRuntimeFault.removedConfigField);
      expect(d.plugin, 'mmparko/dsh-purge');
      expect(d.rawError, thrown);
      expect(d.message, contains('toolFilter'));
    });

    test('"never started" is an Agent Preset that did not mount', () {
      final d = classifyPluginRuntimeError(
        'tool-subagent-list-agents: never started',
        plugin: 'dsh-agent-preset-registry',
      )!;
      expect(d.fault, PluginRuntimeFault.missingAgentPreset);
    });

    test('a missing module is a bad install, not a version mismatch', () {
      final d = classifyPluginRuntimeError(
        "Error: Cannot find module '/x/node_modules/@a/b/lib/index.js'",
        plugin: '@a/b',
      )!;
      expect(d.fault, PluginRuntimeFault.missingPackage);
    });

    test('an error we do not recognise stays unrecognised', () {
      // Guessing here would invent a cause and send someone down the wrong path.
      expect(classifyPluginRuntimeError('boom', plugin: '@a/b'), isNull);
    });
  });

  group('pre-registration checks', () {
    test('a plugin missing from node_modules is a bad install', () {
      final check = checkPluginAtRuntime(
        plugin: '@a/b',
        manifestJson: null,
        runtimeDshVersion: '0.2.0-rc.2',
      );
      expect(check.canRegister, isFalse);
      expect(check.blockers.single.fault, PluginRuntimeFault.missingPackage);
    });

    test('an unreadable package.json is reported, not guessed at', () {
      final check = checkPluginAtRuntime(
        plugin: '@a/b',
        manifestJson: 'not json',
        runtimeDshVersion: '0.2.0-rc.2',
      );
      expect(check.blockers.single.fault, PluginRuntimeFault.unreadableManifest);
    });

    test('an undeclared plugin is allowed but marked unverified', () {
      final check = checkPluginAtRuntime(
        plugin: '@a/b',
        manifestJson: manifest({}),
        runtimeDshVersion: '0.2.0-rc.2',
      );
      expect(check.canRegister, isTrue, reason: 'no declaration is not a conflict');
      expect(check.isUnverified, isTrue);
      expect(check.blockers, isEmpty);
    });

    test('a missing plugin the manifest requires is named', () {
      final check = checkPluginAtRuntime(
        plugin: '@a/b',
        manifestJson: manifest({
          'dsh': {
            'compatibility': {
              'requiresPlugins': ['dsh-tool-subagent', 'dsh-missing'],
            },
          },
        }),
        runtimeDshVersion: '0.2.0-rc.2',
        providedPlugins: {'dsh-tool-subagent'},
      );
      final fault = check.blockers.single;
      expect(fault.fault, PluginRuntimeFault.unresolvedPluginReference);
      expect(fault.message, contains('dsh-missing'));
      // The one that IS provided must not be reported.
      expect(fault.message, isNot(contains('dsh-tool-subagent')));
    });

    test('passing no provided set skips that check instead of failing it', () {
      final check = checkPluginAtRuntime(
        plugin: '@a/b',
        manifestJson: manifest({
          'dsh': {
            'compatibility': {
              'requiresPlugins': ['dsh-anything'],
            },
          },
        }),
        runtimeDshVersion: '0.2.0-rc.2',
      );
      expect(check.blockers, isEmpty);
    });

    test('one bad plugin does not poison the others', () {
      // The isolation contract: each check stands on its own inputs.
      final good = checkPluginAtRuntime(
        plugin: '@a/good',
        manifestJson: manifest({'engines': {'dsh': '>=0.1.0'}}),
        runtimeDshVersion: '0.2.0-rc.2',
      );
      final bad = checkPluginAtRuntime(
        plugin: '@a/bad',
        manifestJson: manifest({}),
        runtimeDshVersion: '0.2.0-rc.2',
        config: {'toolFilter': []},
      );
      expect(good.canRegister, isTrue);
      expect(bad.canRegister, isFalse);
    });
  });

  group('bounded migration', () {
    test('the one known rename applies, and only with its exact shape', () {
      const migration = PluginConfigMigration(
        id: 't',
        plugin: 'dsh-tool-subagent',
        fromField: 'preset',
        toField: 'agentPreset',
        explain: 'x',
      );
      expect(migration.apply({'preset': 'review'}), {'agentPreset': 'review'});
      // Already migrated: nothing to do.
      expect(migration.apply({'agentPreset': 'review'}), isNull);
      // Both present: ambiguous, refuse rather than overwrite.
      expect(migration.apply({'preset': 'a', 'agentPreset': 'b'}), isNull);
      // Absent: not this migration's business.
      expect(migration.apply({'maxDepth': 1}), isNull);
    });

    test('toolFilter / persona are deliberately not auto-migratable', () {
      // Moving a tool allow-list into an Agent Preset changes what the agent
      // may do; the issue forbids doing that on someone's behalf.
      final found = migrationsFor({'toolFilter': ['read'], 'persona': 'x'});
      expect(found, isEmpty);
    });

    test('migrationsFor lists the rename when it is actually applicable', () {
      final found = migrationsFor({'preset': 'review'});
      expect(found.map((m) => m.id), ['subagent-agent-preset']);
    });

    test('applying a migration never mutates the input map', () {
      final original = <String, Object?>{'preset': 'review', 'maxDepth': 3};
      const migration = PluginConfigMigration(
        id: 't',
        plugin: 'dsh-tool-subagent',
        fromField: 'preset',
        toField: 'agentPreset',
        explain: 'x',
      );
      final next = migration.apply(original)!;
      expect(original, {'preset': 'review', 'maxDepth': 3});
      expect(next, {'agentPreset': 'review', 'maxDepth': 3});
      expect(identical(original, next), isFalse);
    });
  });
}