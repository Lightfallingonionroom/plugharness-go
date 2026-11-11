// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
// Local changes: rewritten as floating chrome-glass pieces sharing one
// BackdropGroup, on a measuring row that decides which piece gives way.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/header_schedule_state.dart';
import '../agents/header_agents.dart';
import '../common/fluid_bits.dart';
import '../common/smooth_size.dart';
import '../common/status_dot.dart';
import '../files/files_page.dart';
import '../shell/adaptive/adaptive_scaffold.dart' show AdaptiveChrome;
import '../shell/adaptive/detail_panel_keys.dart';
import '../terminal/terminal_page.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'control_icons.dart';
import 'header_schedule.dart';
import 'model_sheet.dart' show ModelChip;

/// The flat header's own colours, read from the shell palette without making
/// every dark/light decision here.
typedef ChatHeaderColors = ChatGptShellColors;

/// 顶栏状态行的内容:状态点 + 一句人话。颜色从不单独表达状态。
/// 计时只在活动条里,这一行不走秒。
class HeaderStatus {
  const HeaderStatus(this.tone, this.label, {this.spoken});
  final StatusTone tone;
  final String label;

  /// What a screen reader announces instead of [label] (the approval itself,
  /// how the turn ended).
  final String? spoken;
}

/// 聊天顶栏:ChatGPT 式**一条平顶栏**——左键、标题、右侧动作在同一行,
/// 不铺玻璃胶囊,只在内容滚到下面时浮一层页面色渐隐。
///
/// 结构与 ChatGPT 的对话顶栏一致:菜单键在左,对话标题居中偏左(副行是
/// 状态/工作区),右侧是模型与「新对话」。省掉原来三枚玻璃圆钮的层次,
/// 因为平顶栏本身已经是一条清楚的边界;玻璃只留给输入条和浮层。
///
/// ```
/// ☰   修复登录重复提交              ✦ V4 Pro ⌄  ✎
///      ● 生成中
/// ```
class ChatHeader extends ConsumerStatefulWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.status,
    this.detail,
    this.trailing,
    this.onOpenDrawer,
    this.onTitleTap,
    this.onNewChat,
    this.scrolledUnder,
    this.centerLabel,
    this.onCenterTap,
  });

  final String title;
  final HeaderStatus status;

  /// ChatGPT-style centred model selector on the new-chat screen. When set,
  /// the bar is rebuilt as three zones (menu | centred dropdown | new chat)
  /// instead of the left-aligned title pill. The label is deliberately not a
  /// model name: the sheet that opens lists those names, and two copies of the
  /// same Text would break every `find.text` in model_sheet_test.
  final String? centerLabel;
  final Future<void> Function()? onCenterTap;

  /// What follows the status under the title (a phone: the workspace). Shortens first.
  final String? detail;

  /// 右侧件（「查看工作进展」[WorkProgressKey]，或别的东西）。它是定宽的，
  /// 所以顶栏只需要决定标题怎么分剩下的地方。
  /// Null: the title has the room.
  final Widget? trailing;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onTitleTap;
  final VoidCallback? onNewChat;

  /// Whether content has scrolled under the bar, 0..1. Drives the top fade:
  /// at rest the page is one clean surface, the fade only appears once there is
  /// something to fade (same as every secondary page, see `AppPage`). Null
  /// when nothing scrolls (new chat): no fade.
  final ValueListenable<double>? scrolledUnder;

  /// 顶栏的高度(不含状态栏),与二级页面的返回键栏一致。列表顶部留白按它算。
  static const barHeight = 56.0;

  /// The title row: 44 like the keys beside it, taller when large text needs
  /// it for the title and the status line.
  static double pillHeightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(44.0, scaler.scale(15) * 1.3 + scaler.scale(11) * 1.25 + 8);
  }

  static double barHeightOf(BuildContext context) => math.max(barHeight, pillHeightOf(context) + 12);

  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + barHeightOf(context) + 8;

  @override
  ConsumerState<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends ConsumerState<ChatHeader> {
  // Keep TextPainter's paragraph/layout cache across unrelated header rebuilds.
  // Its setters invalidate layout when the label, metrics or direction change.
  final _statusPainter = TextPainter(maxLines: 1);

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _fontsChanged() => setState(_statusPainter.markNeedsLayout);

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _statusPainter.dispose();
    super.dispose();
  }

  bool _centerPressed = false;
  bool _centerOpen = false;

  /// ChatGPT's conversation header: three zones, the tappable model dropdown
  /// dead centre. Built only for the new-chat screen; every other conversation
  /// keeps the title pill with its details, schedule clock and workspace line.
  Widget _centeredBar(
    BuildContext context, {
    required String label,
    required double top,
    required double barHeight,
  }) {
    final l10n = context.l10n;
    final colors = ChatHeaderColors.of(context);
    final standard = AppMotion.of(context, AppMotion.standard);
    final quick = AppMotion.of(context, AppMotion.quick);

    Widget roundKey({
      required Key? key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
    }) =>
        SizedBox.square(
          key: key,
          dimension: 44,
          child: GlassSurface(
            tier: GlassTier.chrome,
            circle: true,
            grouped: true,
            style: colors.flatChrome,
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: Center(child: Icon(icon, size: 22, color: colors.primaryText)),
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, top, 12, 0),
      child: BackdropGroup(
        child: SizedBox(
          key: const ValueKey('chat-header-bar'),
          height: barHeight,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: roundKey(
                  key: const ValueKey('chat-menu'),
                  icon: AppIcons.menu,
                  tooltip: l10n.chatChats,
                  onTap: widget.onOpenDrawer,
                ),
              ),
              // Stack + Center, not a three-cell Row: the dropdown is centred
              // on the screen, not on the gap between two unequal keys.
              Center(
                child: TweenAnimationBuilder<double>(
                  key: const ValueKey('chat-model-select'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: standard,
                  curve: AppMotion.std,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
                  ),
                  child: Semantics(
                    button: true,
                    label: label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => setState(() => _centerPressed = true),
                      onTapUp: (_) => setState(() => _centerPressed = false),
                      onTapCancel: () => setState(() => _centerPressed = false),
                      onTap: _openCenter,
                      child: AnimatedScale(
                        scale: _centerPressed ? 0.94 : 1,
                        duration: quick,
                        curve: AppMotion.std,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Text.rich, not Text(data): the model sheet finds its cards with
                                  // find.text('V4 Pro') / find.text('选择模型'), and a plain
                                  // Text here would be a second hit. find.text only
                                  // matches Text.data by default (findRichText: false),
                                  // so the header can show the very same name without
                                  // making those finders ambiguous. The Semantics
                                  // label above still reads it out.
                                  Text.rich(
                                    TextSpan(text: label),
                                    key: const ValueKey('chat-header-model-name'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: colors.primaryText,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedRotation(
                                    turns: _centerOpen ? 0.5 : 0,
                                    duration: quick,
                                    curve: AppMotion.std,
                                    child: Icon(AppIcons.dropdown, size: 18, color: colors.tertiaryText),
                                  ),
                                ],
                              ),
                              // The engine's state still has a home: a small
                              // second line under the tappable label, the way
                              // ChatGPT leaves room for a short status.
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusDot(tone: widget.status.tone, size: 6),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      widget.status.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontSize: 11,
                                            color: colors.tertiaryText,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: widget.onNewChat == null
                    // Chat GPT's right-hand key has no action on the new-chat
                    // screen. Keep an equal empty cell so the middle stays
                    // optically centred; it must not answer `chat-new-chat`,
                    // which the new-chat screen deliberately does not show.
                    ? const SizedBox.square(key: ValueKey('chat-header-balance'), dimension: 44)
                    : roundKey(
                        key: const ValueKey('chat-new-chat'),
                        icon: AppIcons.newChat,
                        tooltip: l10n.commonNewChat,
                        onTap: widget.onNewChat,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCenter() async {
    setState(() => _centerOpen = true);
    try {
      await widget.onCenterTap?.call();
    } finally {
      if (mounted) setState(() => _centerOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final barHeight = ChatHeader.barHeightOf(context);
    final pillHeight = ChatHeader.pillHeightOf(context);
    // The new-chat screen uses ChatGPT's three-zone bar: the model dropdown
    // sits in the middle and is the thing you tap. Every other conversation
    // keeps the title pill below (its details, schedule clock and workspace
    // line all live there).
    if (widget.centerLabel case final centerLabel?) {
      return _centeredBar(context, label: centerLabel, top: top, barHeight: barHeight);
    }
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: ChatHeaderColors.of(context).primaryText,
    );
    final statusStyle = theme.textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.25);
    final titleFloor = _titleFloor(context, statusStyle);
    // The schedule clock widens the pill by this much over its plain right
    // padding, while the bar can afford it (see [_HeaderRow]).
    final scheduled = ref.watch(headerSchedulesProvider.select((s) => s.shown));
    final clockExtra = scheduled ? HeaderScheduleCap.extraFor(pillHeight) : 0.0;
    // Wide windows: next to the rail (it has its own ≡) the key goes, and ≡
    // says what it does there (fold or unfold the list).
    final chrome = AdaptiveChrome.maybeOf(context);
    // The stack is only as tall as the bar; the fade runs 12dp past it, so it
    // must not clip (a clipped fade is a hard line right under the pills).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: widget.scrolledUnder == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<double>(
                  valueListenable: widget.scrolledUnder!,
                  builder: (context, t, child) => Opacity(opacity: t, child: child),
                  child: TopFade(height: top + barHeight + 12),
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, top, 12, 0),
          child: BackdropGroup(
            child: SizedBox(
              key: const ValueKey('chat-header-bar'),
              height: barHeight,
              child: _HeaderRow(
                titleFloor: titleFloor,
                clockExtra: clockExtra,
                children: [
                  // A subagent conversation shows 「‹ 上级对话」 here.
                  HeaderLeadSlot(
                    menu: !(chrome?.showsMenuKey ?? true)
                        ? const SizedBox.shrink()
                        : SizedBox.square(
                            key: const ValueKey('chat-menu'),
                            dimension: 44,
                            child: GlassSurface(
                              tier: GlassTier.chrome,
                              circle: true,
                              grouped: true,
                              style: ChatHeaderColors.of(context).flatChrome,
                              onTap: widget.onOpenDrawer,
                              child: Tooltip(
                                message: chrome?.menuTooltip ?? l10n.chatChats,
                                child: Center(
                                  child: Icon(
                                    AppIcons.menu,
                                    size: 22,
                                    color: ChatHeaderColors.of(context).primaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  Semantics(
                    button: widget.onTitleTap != null,
                    hint: widget.onTitleTap == null ? null : l10n.chatViewChatDetails,
                    child: GlassSurface(
                      tier: GlassTier.chrome,
                      borderRadius: BorderRadius.circular(AppShape.sm),
                      grouped: true,
                      style: ChatHeaderColors.of(context).flatChrome,
                      onTap: widget.onTitleTap,
                      child: ConstrainedBox(
                        key: const ValueKey('chat-title-pill'),
                        constraints: BoxConstraints(minHeight: pillHeight),
                        child: Padding(
                          // Left 16 only: the schedule cap already stands in
                          // for the pill's right 16 (its own [padding]) when
                          // there is no clock, so a symmetric inset would put
                          // the text 32 in from the end.
                          padding: const EdgeInsets.only(left: 16),
                          // A new title or status, or the clock coming and
                          // going, glides the title block to its new width.
                          child: SmoothSize(
                            duration: AppMotion.of(context, AppMotion.standard),
                            curve: AppMotion.std,
                            alignment: Alignment.centerLeft,
                            child: _PillContent(
                              textFloor: titleFloor - _pillPadding * 2,
                              text: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    HeaderTitleText(widget.title, style: titleStyle),
                                    _StatusLine(
                                      status: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          StatusDot(tone: widget.status.tone, size: _dot),
                                          const SizedBox(width: _dotGap),
                                          Flexible(
                                            child: _StatusLabel(
                                              status: widget.status,
                                              style: statusStyle?.copyWith(
                                                color: widget.status.tone == StatusTone.warn
                                                    ? dsh.warning
                                                    : ChatHeaderColors.of(context).tertiaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      detail: switch (widget.detail) {
                                        final detail? => FluidTextSwap(
                                          value: detail,
                                          child: Text(
                                            ' · $detail',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: statusStyle?.copyWith(
                                              color: ChatHeaderColors.of(context).tertiaryText,
                                            ),
                                          ),
                                        ),
                                        null => const SizedBox.shrink(),
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              end: HeaderScheduleCap(pillHeight: pillHeight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The agents capsule, then the model chip (a subagent
                  // conversation has no model chip). Flexible: the chip
                  // takes the width this row gives it.
                  HeaderTrailingSlot(
                    trailing: switch (widget.trailing) {
                      // 只有可收缩的 ModelChip 挂 _ChipSlot 标记：_RenderHeaderRow 靠
                      // _RenderChipSlot 认出它，在窄屏先压 chip 再给标题留
                      // floor（chat_header_geometry_test 的契约）。定宽的
                      // 工作进展键不标记，_chipIn 返回 null 走宽松路径，
                      // 44 圆钮保持原样、不被当成 36 的 chip 压窄。
                      final trailing? => Flexible(child: trailing is ModelChip ? _ChipSlot(child: trailing) : trailing),
                      null => null,
                    },
                  ),
                  // Mirrors the menu key; gone on the new-chat screen. On a
                  // wide window the key that unfolds 对话详情 follows it.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SmoothSize(
                        duration: AppMotion.of(context, AppMotion.quick),
                        child: widget.onNewChat == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: HeaderTrailingSlot.gap),
                                child: SizedBox.square(
                                  key: const ValueKey('chat-new-chat'),
                                  dimension: 44,
                                  child: GlassSurface(
                                    tier: GlassTier.chrome,
                                    circle: true,
                                    grouped: true,
                                    style: ChatHeaderColors.of(context).flatChrome,
                                    onTap: widget.onNewChat,
                                    child: Tooltip(
                                      message: l10n.commonNewChat,
                                      child: Center(
                                        child: Icon(
                                          AppIcons.newChat,
                                          size: 22,
                                          color: ChatHeaderColors.of(context).primaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const DetailPanelKey(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The pill's text inset, both sides ([HeaderScheduleCap.padding] on the
  /// right, where the clock goes).
  static const _pillPadding = HeaderScheduleCap.padding;
  static const _dot = 6.0;
  static const _dotGap = 5.0;

  /// The least the title pill keeps against the model chip: the title's first
  /// four characters (or all of a shorter one) and the whole status line, the
  /// host's name included, up to eight characters' width.
  double _titleFloor(BuildContext context, TextStyle? statusStyle) {
    final scaler = MediaQuery.textScalerOf(context);
    _statusPainter
      ..text = TextSpan(text: widget.status.label, style: DefaultTextStyle.of(context).style.merge(statusStyle))
      ..textDirection = Directionality.of(context)
      ..textScaler = scaler
      ..layout();
    final statusLine = _dot + _dotGap + _statusPainter.width;
    final title = scaler.scale(15);
    return _pillPadding * 2 + math.max(title * 5, math.min(statusLine, title * 8));
  }
}

/// 顶栏右上角的「查看工作进展」键：**点按开终端，长按开文件**。
///
/// 一个图标两种动作，是用户定的：终端是主操作（所以显示成终端），文件是
/// 长按。两者都是**这个对话**的实际进展（终端跑的是它的工作区，文件列的是
/// 它的目录），不是它的配置——模型、权限、模式都在输入条的「控制面板」里。
class WorkProgressKey extends StatelessWidget {
  const WorkProgressKey({super.key, required this.sessionId});

  final String sessionId;

  /// 键的可见尺寸与点击区，和顶栏其它圆键一致。
  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ChatHeaderColors.of(context);
    return Tooltip(
      message: l10n.chatWorkProgressTooltip,
      child: Semantics(
        button: true,
        label: l10n.chatWorkProgressTooltip,
        onLongPressHint: l10n.chatWorkProgressHoldHint,
        onTap: () => _openTerminal(context),
        onLongPress: () => _openFiles(context),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openTerminal(context),
          onLongPress: () => _openFiles(context),
          child: GlassSurface(
            tier: GlassTier.chrome,
            circle: true,
            grouped: true,
            style: colors.flatChrome,
            child: Center(
              child: ChatGptTerminalIcon(size: 22, color: colors.primaryText),
            ),
          ),
        ),
      ),
    );
  }

  void _openTerminal(BuildContext context) {
    Navigator.of(context).push(TerminalPage.route(sessionId));
  }

  void _openFiles(BuildContext context) {
    Navigator.of(context).push(WorkspaceFilesPage.route(sessionId));
  }
}


/// Marks the model chip inside the trailing pieces, so the bar can weigh its
/// widths apart from the agents capsule beside it.
class _ChipSlot extends SingleChildRenderObjectWidget {
  const _ChipSlot({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderChipSlot();
}

class _RenderChipSlot extends RenderProxyBox {}

/// The bar's pieces on one line: the left key (≡ or the breadcrumb), the
  /// title block, the trailing pieces (agents capsule, the 工作进展 key) and the
  /// 新对话 key.
  ///
  /// The trailing pieces have a fixed width now (the 工作进展 key is a 44 circle,
  /// the agents capsule is its own width), so the bar only has to decide how the
  /// title shares what is left:
  ///
  /// 1. the title takes its whole width when that fits;
  /// 2. else it shortens, down to [titleFloor] (with the schedule clock beside
  ///    it, when the conversation has one);
  /// 3. then the schedule clock goes, [clockExtra] back to the title;
  /// 4. only then does the title go under its floor.
  ///
  /// The pill's content ([_PillContent]) reads step 3 off the width it gets.
  ///
/// The title pill sits 8 after the left key; the trailing pieces end at the
/// 新对话 key (they carry their own 8s); everything centred on one line.
class _HeaderRow extends MultiChildRenderObjectWidget {
  const _HeaderRow({required this.titleFloor, required this.clockExtra, required super.children})
    : assert(children.length == 4);

  final double titleFloor;

  /// How much the schedule clock widens the title pill; 0 without one.
  final double clockExtra;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeaderRow(titleFloor, clockExtra);

  @override
  void updateRenderObject(BuildContext context, _RenderHeaderRow renderObject) {
    renderObject
      ..titleFloor = titleFloor
      ..clockExtra = clockExtra;
  }
}

class _HeaderRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeaderRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderRowParentData> {
  _RenderHeaderRow(this._titleFloor, this._clockExtra);

  static const _gap = HeaderTrailingSlot.gap;

  double _titleFloor;
  set titleFloor(double value) {
    if (value == _titleFloor) return;
    _titleFloor = value;
    markNeedsLayout();
  }

  double _clockExtra;
  set clockExtra(double value) {
    if (value == _clockExtra) return;
    _clockExtra = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderRowParentData) {
      child.parentData = _HeaderRowParentData();
    }
  }

  /// The model chip among the trailing pieces; null when there is none (a
  /// subagent conversation).
  static RenderBox? _chipIn(RenderObject trailing) {
    RenderBox? found;
    void visit(RenderObject node) {
      if (found != null) return;
      if (node is _RenderChipSlot) {
        found = node;
      } else {
        node.visitChildren(visit);
      }
    }
    trailing.visitChildren(visit);
    return found;
  }
  List<RenderBox> get _pieces => getChildrenAsList();

  @override
  double computeMinIntrinsicWidth(double height) =>
      _pieces.fold(_gap, (sum, child) => sum + child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _pieces.fold(_gap, (sum, child) => sum + child.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _pieces.fold(0, (top, child) => math.max(top, child.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _pieces.fold(0, (top, child) => math.max(top, child.getMaxIntrinsicHeight(width)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    final [lead, title, trailing, fresh] = _pieces;
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final loose = BoxConstraints(maxWidth: width, maxHeight: height);
    lead.layout(loose, parentUsesSize: true);
    fresh.layout(loose, parentUsesSize: true);
    // What the title pill and the trailing pieces share.
    // No gap after an empty left piece (≡ handed to the rail).
    final leadEnd = lead.size.width == 0 ? 0.0 : lead.size.width + _gap;
    final room = math.max(0.0, width - leadEnd - fresh.size.width);
    final titleWhole = title.getMaxIntrinsicWidth(height);
    var trailingMax = room;
    if (_chipIn(trailing) case final chip?) {
      final chipWhole = chip.getMaxIntrinsicWidth(height);
      final others = trailing.getMaxIntrinsicWidth(height) - chipWhole;
      final named = others + chip.getMinIntrinsicWidth(height);
      final compact = others + ModelChip.compactWidth;
      // The pill's intrinsic width counts the clock; its floor doesn't.
      final plainWhole = titleWhole - _clockExtra;
      final plainFloor = math.min(_titleFloor, plainWhole);
      // Step 5: the clock stays while the title keeps its floor beside it
      // with the chip down to ✦ ⌄.
      final clock = _clockExtra > 0 && plainFloor + _clockExtra <= room - compact;
      final whole = clock ? titleWhole : plainWhole;
      final floor = clock ? plainFloor + _clockExtra : plainFloor;
      final share = math.min(math.max(floor, math.min(whole, room - named)), math.max(0.0, room - compact));
      trailingMax = room - share;
    }
    trailing.layout(BoxConstraints(maxWidth: math.max(0.0, trailingMax), maxHeight: height), parentUsesSize: true);
    title.layout(
      BoxConstraints(maxWidth: math.max(0.0, room - trailing.size.width), maxHeight: height),
      parentUsesSize: true,
    );
    void place(RenderBox child, double x) =>
        (child.parentData! as _HeaderRowParentData).offset = Offset(x, (height - child.size.height) / 2);
    place(lead, 0);
    place(title, leadEnd);
    place(fresh, width - fresh.size.width);
    place(trailing, width - fresh.size.width - trailing.size.width);
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// The title pill's content: the title and status lines, then the pill's
/// right end ([end]: its plain padding, or the schedule clock).
///
/// The clock shows while the lines keep their floor ([textFloor], or all of
/// a shorter title) beside it in the width the bar gives; otherwise the end
/// is the plain padding and the clock is neither painted, hit nor read out.
/// The bar ([_HeaderRow]) allocates by the same rule, so the clock goes
/// before the title would shorten under its floor.
class _PillContent extends MultiChildRenderObjectWidget {
  _PillContent({required this.textFloor, required Widget text, required Widget end}) : super(children: [text, end]);

  /// The least width the title and status lines keep beside the clock.
  final double textFloor;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPillContent(textFloor);

  @override
  void updateRenderObject(BuildContext context, _RenderPillContent renderObject) {
    renderObject.textFloor = textFloor;
  }
}

class _PillContentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPillContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PillContentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PillContentParentData> {
  _RenderPillContent(this._textFloor);

  /// Rounding between the bar's arithmetic and the measured widths.
  static const _slack = 0.5;

  double _textFloor;
  set textFloor(double value) {
    if (value == _textFloor) return;
    _textFloor = value;
    markNeedsLayout();
  }

  /// Whether the end is the clock and on screen.
  bool _showsEnd = true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PillContentParentData) {
      child.parentData = _PillContentParentData();
    }
  }

  RenderBox get _text => firstChild!;
  RenderBox get _end => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) => _text.getMinIntrinsicWidth(height) + _ChatHeaderState._pillPadding;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height) + _end.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(_text.getMinIntrinsicHeight(width), _end.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(_text.getMaxIntrinsicHeight(width), _end.getMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(
    Size(computeMaxIntrinsicWidth(constraints.maxHeight), computeMaxIntrinsicHeight(double.infinity)),
  );

  @override
  void performLayout() {
    final text = _text;
    final end = _end;
    final height = constraints.maxHeight;
    final endWhole = end.getMaxIntrinsicWidth(height);
    final clock = endWhole > _ChatHeaderState._pillPadding + _slack;
    final textFloor = math.min(_textFloor, text.getMaxIntrinsicWidth(height));
    _showsEnd = !clock || textFloor + endWhole <= constraints.maxWidth + _slack;
    end.layout(BoxConstraints(maxHeight: height), parentUsesSize: true);
    final endWidth = _showsEnd ? end.size.width : _ChatHeaderState._pillPadding;
    text.layout(
      BoxConstraints(maxWidth: math.max(0.0, constraints.maxWidth - endWidth), maxHeight: height),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(text.size.width + endWidth, math.max(text.size.height, _showsEnd ? end.size.height : 0)),
    );
    (text.parentData! as _PillContentParentData).offset = Offset(0, (size.height - text.size.height) / 2);
    (end.parentData! as _PillContentParentData).offset = Offset(text.size.width, (size.height - end.size.height) / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(_text, (_text.parentData! as _PillContentParentData).offset + offset);
    if (_showsEnd) {
      context.paintChild(_end, (_end.parentData! as _PillContentParentData).offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [if (_showsEnd) _end, _text]) {
      final offset = (child.parentData! as _PillContentParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_text);
    if (_showsEnd) visitor(_end);
  }
}

/// 状态文字;读屏的实时区域,变了就播报 [HeaderStatus.spoken] 或文字本身。
/// The line under the title: the status first, whatever it needs, and the detail in what
/// is left. A flex would hold back a share for each, cutting one with room beside it.
class _StatusLine extends MultiChildRenderObjectWidget {
  _StatusLine({required Widget status, required Widget detail}) : super(children: [status, detail]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStatusLine();
}

class _StatusLineParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderStatusLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StatusLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _StatusLineParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StatusLineParentData) child.parentData = _StatusLineParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      getChildrenAsList().fold(0.0, (sum, child) => sum + child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      getChildrenAsList().fold(0.0, (sum, child) => sum + child.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      getChildrenAsList().fold(0.0, (most, child) => math.max(most, child.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getChildrenAsList().fold(0.0, (most, child) => math.max(most, child.getMaxIntrinsicHeight(width)));

  (Size, Size) _measure(BoxConstraints constraints, ChildLayouter layoutChild) {
    final width = constraints.maxWidth;
    final status = layoutChild(firstChild!, BoxConstraints(maxWidth: width));
    final detail = layoutChild(lastChild!, BoxConstraints(maxWidth: math.max(0.0, width - status.width)));
    return (status, detail);
  }

  Size _sizeOf(BoxConstraints constraints, Size status, Size detail) =>
      constraints.constrain(Size(status.width + detail.width, math.max(status.height, detail.height)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final (status, detail) = _measure(constraints, ChildLayoutHelper.dryLayoutChild);
    return _sizeOf(constraints, status, detail);
  }

  @override
  void performLayout() {
    final (status, detail) = _measure(constraints, ChildLayoutHelper.layoutChild);
    size = _sizeOf(constraints, status, detail);
    (firstChild!.parentData! as _StatusLineParentData).offset = Offset(0, (size.height - status.height) / 2);
    (lastChild!.parentData! as _StatusLineParentData).offset = Offset(
      status.width,
      (size.height - detail.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.style});

  final HeaderStatus status;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: status.spoken ?? status.label,
    excludeSemantics: true,
    child: FluidTextSwap(
      value: status.label,
      child: Text(status.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    ),
  );
}
