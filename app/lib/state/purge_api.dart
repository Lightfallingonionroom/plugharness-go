// The bundled dsh-purge-go plugin's HTTP routes, over the app's engine
// connection. The plugin is loaded by path from the runtime overlay; these are
// the same routes its web client calls.

import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_state.dart';

class PurgeApi {
  PurgeApi(this.connection);

  final DshConnection connection;

  static Map<String, dynamic> _json(DshHttpResponse response) {
    final data = jsonDecode(response.text);
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('purge: unexpected response');
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final response = await connection.get(path, query: query);
    return _json(response);
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await connection.postJson(path, body ?? const {});
    return _json(response);
  }

  Future<Map<String, dynamic>> status() => _get('/dsh-purge/status');

  Future<Map<String, dynamic>> apply({String? content}) {
    if (content == null) return _post('/dsh-purge/apply');
    return _post('/dsh-purge/apply', {'content': content});
  }

  Future<Map<String, dynamic>> revert() => _post('/dsh-purge/revert');

  Future<Map<String, dynamic>> uninstall() => _post('/dsh-purge/uninstall');

  Future<Map<String, dynamic>> restart() => _post('/dsh-purge/restart');

  Future<Map<String, dynamic>> restartDismiss() => _post('/dsh-purge/restart-dismiss');

  Future<Map<String, dynamic>> hooksDeny([bool? bypass]) async {
    if (bypass == null) return _get('/dsh-purge/hooks-deny');
    return _post('/dsh-purge/hooks-deny', {'hooksDenyBypass': bypass});
  }

  Future<Map<String, dynamic>> override([String? content]) async {
    if (content == null) return _get('/dsh-purge/override');
    return _post('/dsh-purge/override', {'content': content});
  }

  Future<Map<String, dynamic>> rules(String op, [Map<String, dynamic>? body]) async {
    if (op == 'status') return _get('/dsh-purge/rules');
    return _post('/dsh-purge/rules', {'op': op, ...?body});
  }

  Future<Map<String, dynamic>> skills(String op, [Map<String, dynamic>? body]) async {
    if (op == 'status') return _get('/dsh-purge/skills');
    return _post('/dsh-purge/skills', {'op': op, ...?body});
  }

  Future<Map<String, dynamic>> drillGrant() => _get('/dsh-purge/drill-grant');

  Future<Map<String, dynamic>> grantDrill() => _post('/dsh-purge/drill-grant');

  Future<Map<String, dynamic>> update([String op = 'check']) =>
      _get('/dsh-purge/update', query: {'op': op});

  Future<Map<String, dynamic>> rewindOptions(String sessionId) =>
      _get('/dsh-purge/rewind/options', query: {'sessionId': sessionId});

  Future<Map<String, dynamic>> rewind(String sessionId, {String mode = 'once'}) =>
      _post('/dsh-purge/rewind', {'sessionId': sessionId, 'mode': mode});

  /// Switch the bundled purge version; the overlay is rewritten and the engine
  /// must be restarted for the new plugin path to load.
  Future<Map<String, dynamic>> switchVersion(String version) =>
      _post('/dsh-purge/switch-version', {'version': version});
}

/// The plugin API for the active local engine; null while it is not connected.
final purgeApiProvider = Provider<PurgeApi?>((ref) {
  final host = ref.watch(localConnectionProvider).value;
  final client = host?.client;
  if (client == null) return null;
  return PurgeApi(client.connection);
});
