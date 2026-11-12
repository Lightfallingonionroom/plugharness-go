// Opening the active host's DSH Web in the system browser.
//
// The in-app WebView keeps its own launch-token URL (see local_web_screen.dart);
// this file hands the same live address to an external browser. A short press
// on a web entry still opens the WebView; a long press calls this function.
// The engine issues a fresh token at every restart, so the URL is read at
// gesture time, never cached here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_state.dart';
import 'dsh_web_launcher.dart';
import 'local_web_screen.dart';

/// Opens the active host's DSH Web in the system browser (long-press action).
///
/// Local and SSH hosts already publish exactly what the in-app WebView opens;
/// reusing those providers keeps the external link in step with engine restarts
/// (a new launch token) and with SSH reconnects (a new forward port).
Future<void> openDshWebExternally(BuildContext context, WidgetRef ref) async {
  Uri? uri;
  switch (ref.read(dshWebAccessProvider)) {
    case LocalDshWeb():
      final status = ref.read(localRuntimeProvider).status;
      if (status.isRunning) uri = localWebUri(status.baseUrl!, status.token!);
    case SshDshWeb(:final url):
      uri = url;
    case NoDshWeb(:final reason):
      _snack(context, reason);
      return;
  }
  if (uri == null) {
    _snack(context, context.l10n.webBrowserUnavailable);
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _snack(context, context.l10n.webBrowserUnavailable);
  } catch (_) {
    if (context.mounted) _snack(context, context.l10n.webBrowserUnavailable);
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
}
