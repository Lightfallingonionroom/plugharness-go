// 容器终端: the runtime's own shell, independent of the engine. The engine may be
// down (a plugin broke it, a bad config); this page still runs, so the user can
// remove the plugin, fix the config and start the engine again.
//
// A real PTY (flutter_pty) drives the container's /bin/bash, so the shell has its
// prompt, line editing and job control; the screen is the app's own xterm view,
// with the phone key row under it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../state/terminal_state.dart' show terminalFontSizeProvider;
import '../common/empty_view.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'terminal_keyboard.dart';
import 'terminal_keys.dart';
import 'terminal_palette.dart';
import 'terminal_screen.dart' show TerminalCardFrame;

/// The container's shell page: the xterm screen over the phone key row.
class ContainerTerminalPage extends ConsumerStatefulWidget {
  const ContainerTerminalPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ContainerTerminalPage());

  @override
  ConsumerState<ContainerTerminalPage> createState() => _ContainerTerminalPageState();
}

class _ContainerTerminalPageState extends ConsumerState<ContainerTerminalPage> {
  static const _methods = MethodChannel('dsh/container_terminal');

  final _terminal = Terminal();
  final _modifiers = TerminalModifiers();
  final _focus = FocusNode();
  final _selection = TerminalController();
  final _scroll = ScrollController();

  Pty? _pty;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) => _pty?.write(Uint8List.fromList(utf8.encode(data)));
    unawaited(_start());
  }

  @override
  void dispose() {
    _pty?.kill();
    _modifiers.dispose();
    _focus.dispose();
    _selection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final spec = await _methods.invokeMethod<Map<Object?, Object?>>('shellSpec');
      if (!mounted) return;
      if (spec == null) {
        setState(() {
          _starting = false;
          _error = '容器运行时未安装';
        });
        return;
      }
      final pty = Pty.start(
        spec['executable'] as String,
        arguments: List<String>.from(spec['arguments'] as List),
        environment: Map<String, String>.from(spec['environment'] as Map),
        rows: 30,
        columns: 90,
      );
      _pty = pty;
      pty.output.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
        _toBottom();
      });
      pty.exitCode.then((code) {
        if (mounted) setState(() {});
      });
      setState(() => _starting = false);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error.message ?? error.code;
      });
    }
  }

  // ── Input ──

  void _toBottom() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _onText(String text) {
    if (_modifiers.any && text.runes.length == 1) {
      final m = _modifiers.consume();
      _terminal.textInput(withModifiers(text, ctrl: m.ctrl, alt: m.alt));
    } else {
      _terminal.textInput(text);
    }
    _toBottom();
  }

  void _onBackspace() {
    final m = _modifiers.consume();
    _terminal.keyInput(TerminalKey.backspace, ctrl: m.ctrl, alt: m.alt);
    _toBottom();
  }

  void _onEnter() {
    final m = _modifiers.consume();
    _terminal.keyInput(TerminalKey.enter, ctrl: m.ctrl, alt: m.alt);
    _toBottom();
  }

  void _onExtraKey(TerminalExtraKey key) {
    final m = _modifiers.consume();
    key.send(_terminal, ctrl: m.ctrl, alt: m.alt);
    _toBottom();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_modifiers.any) return KeyEventResult.ignored;
    final character = event.character;
    if (character == null || character.runes.length != 1 || character.codeUnitAt(0) < 0x20) {
      return KeyEventResult.ignored;
    }
    _onText(character);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final font = ref.watch(terminalFontSizeProvider);
    final palette = TerminalPalette.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (_starting) {
      body = Center(child: CircularProgressIndicator(color: scheme.primary));
    } else if (_error != null) {
      body = EmptyView(
        icon: AppIcons.terminal,
        title: _error!,
        actionLabel: '重试',
        onAction: () => unawaited(_start()),
      );
    } else {
      body = TerminalKeyboard(
        focusNode: _focus,
        enabled: true,
        onText: _onText,
        onBackspace: _onBackspace,
        onEnter: _onEnter,
        onComposing: (_) {},
        child: TerminalView(
          _terminal,
          controller: _selection,
          scrollController: _scroll,
          theme: palette.theme,
          textStyle: TerminalStyle(
            fontSize: font,
            fontFamily: AppType.monoFamily,
            fontFamilyFallback: AppType.monoFallback,
          ),
          backgroundOpacity: 0,
          focusNode: _focus,
          autofocus: true,
          hardwareKeyboardOnly: true,
          keyboardAppearance: Brightness.dark,
          onKeyEvent: _onKeyEvent,
        ),
      );
    }

    return AppPage(
      title: '容器终端',
      showLargeTitle: false,
      actions: [
        if (!_starting && _error == null)
          TextButton(
            onPressed: () {
              _pty?.kill();
              _pty = null;
              unawaited(_start());
            },
            child: const Text('重启'),
          ),
      ],
      slivers: [
        SliverFillRemaining(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TerminalCardFrame(child: body),
                ),
              ),
              if (!_starting && _error == null) ...[
                ExtraKeysRow(modifiers: _modifiers, onKey: _onExtraKey),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
