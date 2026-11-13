// 容器终端: the runtime's own shell, independent of the engine. The engine may be
// down (a plugin broke it, a bad config); this page still runs, so the user can
// remove the plugin, fix the config and start the engine again.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/empty_view.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// The container's shell page: a scrollable output area over one input row.
/// The shell is a persistent `/bin/sh` in the runtime rootfs (see
/// `ContainerTerminalPlugin`); output arrives on the event channel.
class ContainerTerminalPage extends ConsumerStatefulWidget {
  const ContainerTerminalPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ContainerTerminalPage());

  @override
  ConsumerState<ContainerTerminalPage> createState() => _ContainerTerminalPageState();
}

class _ContainerTerminalPageState extends ConsumerState<ContainerTerminalPage> {
  static const _methods = MethodChannel('dsh/container_terminal');
  static const _output = EventChannel('dsh/container_terminal/output');

  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<Object?>? _subscription;

  /// The shell's output, oldest first. One string per line keeps the list cheap.
  final List<String> _lines = <String>[];

  bool _starting = true;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listen();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _input.dispose();
    _scroll.dispose();
    // The shell outlives the page: the user may want it still running.
    super.dispose();
  }

  void _listen() {
    _subscription = _output.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final kind = event['event'];
        if (kind == 'output') {
          final text = event['text'];
          if (text is String && text.isNotEmpty) _append(text);
        } else if (kind == 'exit') {
          if (mounted) setState(() => _running = false);
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _error = '断了');
      },
    );
  }

  Future<void> _start() async {
    try {
      await _methods.invokeMethod<bool>('start');
      if (!mounted) return;
      setState(() {
        _starting = false;
        _running = true;
        _error = null;
      });
      _append('\$ ');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error.message ?? error.code;
      });
    }
  }

  void _append(String text) {
    if (!mounted) return;
    setState(() {
      // A chunk may hold several lines; keep them apart so the list stays readable.
      _lines.addAll(text.split('\n'));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.isEmpty) return;
    _input.clear();
    _append('\$ $text');
    try {
      await _methods.invokeMethod<bool>('write', {'text': text});
    } on PlatformException catch (error) {
      _append('[${error.code}] ${error.message ?? ''}');
    }
  }

  Future<void> _stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } on PlatformException {
      // Already gone.
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DshColors.of(context);
    return AppPage(
      title: '容器终端',
      showLargeTitle: false,
      actions: [
        if (_running)
          TextButton(onPressed: _stop, child: Text('停止'))
        else if (!_starting)
          TextButton(onPressed: _start, child: Text('启动')),
      ],
      slivers: [
        SliverFillRemaining(
          child: Column(
            children: [
              Expanded(
                child: _starting
                    ? Center(child: CircularProgressIndicator(color: colors.primary))
                    : _error != null
                        ? EmptyView(icon: AppIcons.plugin, title: _error!)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) => Text(
                              _lines[index],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.35,
                                color: _lines[index].startsWith('[') ? colors.textSecondary : colors.textPrimary,
                              ),
                            ),
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: _running,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: '输入命令…',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _running ? _send : null,
                        child: Text('执行'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
