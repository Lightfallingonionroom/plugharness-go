// Structure derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_bridge.dart';
import '../../runtime/runtime_state.dart';
import '../../state/cordis_state.dart';
import '../../state/bots_state.dart';
import '../../state/connection_state.dart';
import '../../state/engine_control.dart';
import '../../state/drawer_view_state.dart';
import '../../state/session_attention_state.dart';
import '../../state/session_deletion_state.dart';
import '../../state/sessions_state.dart';
import '../../state/read_list_identity.dart';
import '../../state/workspaces_state.dart';
import '../bots/bots_page.dart' show BotsPage, UnreadBadge;
import '../chat/control_icons.dart';
import '../chat/media/media_format.dart' show chatTitleShown;
import '../common/app_dialog.dart';
import '../common/app_sheet.dart';
import '../common/empty_view.dart';
import '../common/expand_reveal.dart';
import '../common/pressable.dart';
import '../common/smooth_size.dart';
import '../common/read_list_status.dart';
import '../common/status_dot.dart';
import '../onboarding/local_install.dart';
import '../safe_mode/engine_failure_card.dart';
import '../safe_mode/safe_mode_banner.dart';
import '../share/share_entry.dart';
import '../engine/engine_screen.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import '../workspace/workspace_switcher.dart';
import '../workspace/workspaces_page.dart';
import 'drawer/drawer_actions.dart';
import 'drawer/drawer_destination.dart';
import 'drawer/archive_notice.dart';
import 'drawer/drawer_filter_bar.dart';
import 'drawer/drawer_list.dart';
import 'drawer/selection_bars.dart';
import 'drawer/session_deletion.dart';
import 'quick_panel.dart' show QuickPanelRow;
import 'session_search_page.dart';

export '../../state/drawer_view_state.dart' show SessionDay, sessionDayOf;
export 'drawer/drawer_destination.dart';
export 'drawer/session_tile.dart' show SessionTile;

/// Display title for a session: DSH's generated title (a generation
/// request's header left out), else a neutral fallback.
String sessionTitle(SessionSummary s) {
  final t = s.title?.trim();
  return t == null || t.isEmpty ? appL10n.commonUntitledChat : chatTitleShown(t);
}

/// The soft fill behind the current conversation (drawer and search).
Color sessionSelectionColor(BuildContext context) {
  final shell = ChatGptShellColors.of(context);
  return shell.rowSelected;
}

/// The sessions drawer, laid out the way ChatGPT lays out its sidebar: the
/// brand and the search key are pinned, and **one** scroll body below them
/// carries the feature rows, the conversation heading, the workspace, the
/// filters and the conversations themselves.
///
/// Why one body: the feature rows used to be fixed above a separate list, so
/// on a phone they pushed the conversations off the screen. Folding the
/// features into the same scroll means the whole column scrolls as a unit —
/// the same gesture, no second scrollable to fight.
///
/// The bottom bar (新对话 + 设置) is pinned like the top. In multi-select the
/// pinned brand row gives way to the selection header, and the bottom bar to
/// the action bar, so 完成 lands exactly where 新对话 was.
class SessionsDrawer extends ConsumerWidget {
  const SessionsDrawer({
    super.key,
    required this.onClose,
    required this.onOpen,
    this.now,
    this.identityBarHeight,
    this.drawerMotion,
  });

  final VoidCallback onClose;
  final ValueChanged<DrawerDestination> onOpen;

  /// Clock override for grouping (tests).
  final DateTime? now;

  /// Told the height of the identity bar (and of the action bar over it in
  /// multi-select) once it is laid out: the pulled-over drawer's notices
  /// stand above it.
  final ValueNotifier<double>? identityBarHeight;

  /// The pulled-over drawer's 0 → 1 animation (null for the persistent
  /// sidebar). While it moves, the panel drops its backdrop blur: a moving
  /// glass surface re-samples the whole chat behind it every frame, which is
  /// the expensive part on mid-range GPUs.
  final Animation<double>? drawerMotion;

  /// Where the content sits in from either edge: the search bar, the rows'
  /// highlights and the identity bar's keys.
  static const contentEdge = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    void newChat() {
      ref.read(currentSessionProvider.notifier).select(null);
      onClose();
    }

    void manageWorkspaces() {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkspacesPage()));
      // Close once the page covers us, so "back" lands on the chat.
      Future<void>.delayed(AppMotion.slow, onClose);
    }

    final selecting =
        ref.watch(drawerSelectionProvider.select((s) => s != null)) && ref.watch(drawerScopeProvider)?.readOnly != true;
    // The drawer stays mounted with the shell: it keeps the unread record
    // following what the person opens and leaves.
    ref.listen(drawerSeenProvider, (_, _) {});
    // Folders forget conversations the host no longer has.
    ref.listen(sessionsProvider, (_, next) {
      if (!next.hasValue || next.isLoading) return;
      final known = {for (final s in ref.read(sessionsProvider.notifier).allSessions) s.sessionId};
      if (known.isNotEmpty) unawaited(ref.read(drawerViewProvider.notifier).forgetMissing(known));
    });
    // Hidden (closed by a tap, a swipe or back): multi-select ends with it.
    if (selecting && !TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.read(drawerSelectionProvider.notifier).end();
      });
    }
    final quick = AppMotion.of(context, AppMotion.quick);
    final shell = ChatGptShellColors.of(context);
    // Pinned at the top: the brand word and the search key. ChatGPT keeps
    // exactly these two in place while everything below them scrolls.
    final pinned = <Widget>[
      AnimatedSwitcher(
        duration: quick,
        child: selecting
            ? DrawerSelectionHeader(key: const ValueKey('selecting'), now: now)
            : Padding(
                key: const ValueKey('brand'),
                // The word on the rows' 20 line, the search key ending on the
                // 10 line; the same 14 / 10 box as [DrawerSelectionHeader],
                // so 完成 lands exactly where the word was.
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                child: Row(
                  children: [
                    // Plain wordmark, no glyph: ChatGPT's sidebar is a word at
                    // the top left, and the whale belongs to the empty state.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Semantics(
                            header: true,
                            child: Text(
                              'PlugHarness',
                              key: const ValueKey('drawer-wordmark'),
                              style: AppType.wordmark(size: 19, color: shell.primaryText),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _DrawerSearchKey(onClose: onClose),
                  ],
                ),
              ),
      ),
      SafeModeBanner(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        onDetails: () => onOpen(DrawerDestination.engine),
      ),
    ];
    // One scroll body: the feature rows (the three that stay, then 更多), the
    // conversation heading, the workspace, the filters, then the conversations.
    // [DrawerConversationList] supplies the conversation part as a sliver, so
    // its rows keep the lazy builder and the keyed index map.
    final body = _EdgeFade(
      child: CustomScrollView(
        physics: AppMotion.scrollPhysics(context),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel(context, l10n.searchFeatures),
                // 插件 / 自动化任务 / 网页版: the three that stay on the top
                // level. 快捷入口's own picks are not repeated here — the
                // drawer is their home now.
                for (final destination in const [
                  DrawerDestination.plugins,
                  DrawerDestination.schedules,
                  DrawerDestination.web,
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: QuickPanelRow(destination: destination, onTap: () => onOpen(destination)),
                  ),
                _DrawerMoreRow(
                  // 本机引擎 / 远程主机 / 全部功能: one level down, opened in
                  // place rather than on another page.
                  destinations: const [
                    DrawerDestination.engine,
                    DrawerDestination.remote,
                    DrawerDestination.features,
                  ],
                  onOpen: onOpen,
                ),
                _sectionLabel(context, l10n.chatChat),
                SmoothSize(
                  duration: AppMotion.of(context, AppMotion.standard),
                  curve: AppMotion.std,
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      Expanded(child: WorkspaceSwitcher(onManage: manageWorkspaces)),
                      _ViewOptionsKey(onClose: onClose),
                    ],
                  ),
                ),
                SmoothSize(
                  duration: AppMotion.of(context, AppMotion.standard),
                  curve: AppMotion.std,
                  alignment: Alignment.topCenter,
                  child: const DrawerFilterBar(),
                ),
              ],
            ),
          ),
          _DrawerConversationSliver(onClose: onClose, now: now),
          // Room to scroll the last rows clear of the pinned bar.
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );

    const radius = BorderRadius.only(topRight: Radius.circular(AppShape.xl), bottomRight: Radius.circular(AppShape.xl));
    final content = Material(
      color: shell.sidebar,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned: brand + search. Stays put while the body scrolls.
            ...pinned,
            Expanded(child: body),
            // The bar over the bottom edge: 新对话 at the left, the settings key
            // at the right. The host pill is gone — ChatGPT's sidebar ends with
            // its account key, and the engine's state has the header and the
            // empty state to say it.
            // The action bar lies exactly over this bar, which keeps its size
            // while hidden: same height at any text size.
            _ReportHeight(
              height: identityBarHeight,
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: selecting ? 0 : 1,
                    duration: quick,
                    child: IgnorePointer(
                      ignoring: selecting,
                      child: ExcludeSemantics(
                        excluding: selecting,
                        child: DrawerBottomBar(
                          onNewChat: newChat,
                          onSettings: () => onOpen(DrawerDestination.settings),
                          onSettingsHold: () => onOpen(DrawerDestination.settingsSearch),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: quick,
                      child: selecting
                          ? SelectionActionBar(
                              key: const ValueKey('selecting'),
                              onMove: () {
                                if (ref.read(drawerScopeProvider)?.readOnly == false) {
                                  moveToFolderFlow(
                                    context,
                                    ref,
                                    ref.read(drawerSelectionProvider)?.toList() ?? const [],
                                  );
                                }
                              },
                              onPin: () {
                                if (ref.read(drawerScopeProvider)?.readOnly == false) pinSelectionFlow(context, ref);
                              },
                              onArchive: () {
                                if (ref.read(drawerScopeProvider)?.readOnly == false) {
                                  archiveSelectionFlow(context, ref);
                                }
                              },
                              onDelete: () {
                                if (ref.read(drawerScopeProvider)?.readOnly == false) {
                                  unawaited(deleteSelectionFlow(context, ref));
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final motion = drawerMotion;
    if (motion == null) {
      return GlassSurface(
        tier: GlassTier.sheet,
        borderRadius: radius,
        style: shell.sidebarGlass,
        child: content,
      );
    }
    return SlidingGlass(
      motion: motion,
      tier: GlassTier.sheet,
      borderRadius: radius,
      style: shell.sidebarGlass,
      child: content,
    );
  }
}

/// A section heading in the one-column drawer, the way ChatGPT labels
/// its pinned rooms and its conversation list: small, quiet, left aligned.
Widget _sectionLabel(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ChatGptShellColors.of(context).tertiaryText,
            ),
      ),
    );

/// Tells [height] the child's height after each layout that changes it (on
/// the next frame: nothing above is rebuilt while laying out).
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.height, required super.child});

  final ValueNotifier<double>? height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportHeight(height);

  @override
  void updateRenderObject(BuildContext context, _RenderReportHeight renderObject) => renderObject.height = height;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.height);

  ValueNotifier<double>? height;

  @override
  void performLayout() {
    super.performLayout();
    final target = height;
    final value = size.height;
    if (target == null || target.value == value) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && identical(height, target)) target.value = value;
    });
  }
}

/// "新对话": the drawer's one solid primary element. ChatGPT draws it as a
/// 36dp circle holding just the compose glyph; the words live in the tooltip
/// and the semantics label, so the brand row keeps its room.
class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = ChatGptShellColors.of(context);
    return Tooltip(
      message: l10n.commonNewChat,
      child: Semantics(
        button: true,
        label: l10n.commonNewChat,
        onTap: onTap,
        excludeSemantics: true,
        child: Pressable(
          child: Material(
            color: shell.primaryAction,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Icon(AppIcons.newChat, size: 19, color: shell.onPrimaryAction),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「对话列表」 options at the end of the workspace row, its circle on the 10
/// line; only while there are conversations to organise.
class _ViewOptionsKey extends ConsumerWidget {
  const _ViewOptionsKey({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(drawerScopeProvider);
    final filtered = ref.watch(drawerFilterProvider) != DrawerFilter.all;
    ref.watch(sessionsProvider);
    final hasArchived = ref.read(sessionsProvider.notifier).archivedSessions.isNotEmpty;
    if (scope == null || (scope.sessions.isEmpty && !filtered && !hasArchived)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: DrawerViewButton(onTap: () => openDrawerViewOptions(context, ref, onClose: onClose)),
    );
  }
}

/// The drawer's pinned search key: a 36 circle like 新对话, opening the same
/// conversation search the search field used to.
class _DrawerSearchKey extends StatelessWidget {
  const _DrawerSearchKey({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = ChatGptShellColors.of(context);
    return Tooltip(
      message: l10n.shellSearchChats,
      child: Semantics(
        button: true,
        label: l10n.shellSearchChats,
        onTap: () => unawaited(showSessionSearch(context)),
        excludeSemantics: true,
        child: Pressable(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => unawaited(showSessionSearch(context)),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(AppIcons.search, size: 20, color: shell.secondaryText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The feature rows one level down: a 「更多 ▸」 row that opens in place.
///
/// In place, not another page: ChatGPT folds its extra rooms the same way, and
/// a second page would mean a back press to get back to the list.
class _DrawerMoreRow extends StatefulWidget {
  const _DrawerMoreRow({required this.destinations, required this.onOpen});

  final List<DrawerDestination> destinations;
  final ValueChanged<DrawerDestination> onOpen;

  @override
  State<_DrawerMoreRow> createState() => _DrawerMoreRowState();
}

class _DrawerMoreRowState extends State<_DrawerMoreRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = ChatGptShellColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The row itself: 「更多」+ a chevron that turns.
        Semantics(
          button: true,
          expanded: _open,
          label: l10n.commonMore,
          onTap: () => setState(() => _open = !_open),
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('drawer-more'),
            onTap: () => setState(() => _open = !_open),
            customBorder: Squircle.border(AppShape.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(AppIcons.expand, size: 20, color: shell.secondaryText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.commonMore,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: AppMotion.of(context, AppMotion.quick),
                      child: Icon(AppIcons.expand, size: 16, color: shell.tertiaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ExpandReveal(
          open: _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final destination in widget.destinations)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: QuickPanelRow(destination: destination, onTap: () => widget.onOpen(destination)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft top and bottom edges on the list, so rows fade into the header and
/// the identity bar instead of being cut. At rest nothing is under either fade
/// (the list's own padding is deeper).
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  static const _top = 10.0;
  static const _bottom = 16.0;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final h = rect.height <= 0 ? 1.0 : rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, (_top / h).clamp(0.0, 0.5), (1 - _bottom / h).clamp(0.5, 1.0), 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
/// The conversation part of the drawer's one scroll body.
///
/// The states that are not a list (loading, error, no scope yet, an empty
/// host) become their own sliver; the rows come from [DrawerConversationList].
class _DrawerConversationSliver extends ConsumerWidget {
  const _DrawerConversationSliver({required this.onClose, this.now});

  final VoidCallback onClose;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsProvider);
    final identity = ref.watch(readListIdentityProvider);
    final workspace = ref.watch(selectedWorkspaceProvider);
    // Null while loading, or while a selected workspace's members haven't
    // arrived (rather than flash every conversation).
    final scope = ref.watch(drawerScopeProvider);
    if (scope == null) {
      if (ref.watch(readListLiveConnectionProvider) == null && !sessions.isLoading) {
        return SliverToBoxAdapter(child: _Centered(child: _EmptyState()));
      }
      if (sessions.hasError) {
        return SliverToBoxAdapter(
          child: _Centered(
            child: EmptyView(
              compact: true,
              icon: AppIcons.offline,
              title: l10n.shellChatsLoadFailed,
              actionLabel: l10n.commonRetry,
              onAction: () => ref.read(sessionsProvider.notifier).refresh(),
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(child: _SkeletonList());
    }
    // DS Bot's conversations (its Bots' chats, groups, members' sessions)
    // fold into one row that opens the Bot pages.
    final botReady = ref.watch(dsBotProvider.select((s) => s.ready));
    final showBots = scope.bots.isNotEmpty || (workspace == null && botReady);
    if (scope.sessions.isEmpty && !showBots && ref.watch(drawerViewProvider).folders.isEmpty) {
      if (scope.readOnly) {
        return SliverToBoxAdapter(child: _Centered(child: Text(readListStatusText(scope.status))));
      }
      return SliverToBoxAdapter(
        child: workspace == null ? _Centered(child: _EmptyState()) : const _WorkspaceEmptyState(),
      );
    }
    return DrawerConversationList(
      now: now,
      onNewChat: onClose,
      readOnly: scope.readOnly,
      leading: showBots
          ? DsBotDrawerRow(
              running: scope.bots.any((s) => s.running),
              onTap: () {
                Navigator.of(context).push(BotsPage.route());
                // Close once the page covers us, so "back" lands on the chat.
                Future<void>.delayed(AppMotion.slow, onClose);
              },
            )
          : null,
      onOpen: (id) {
        if (ref.read(readListIdentityProvider) != identity ||
            ref.read(drawerScopeProvider)?.sessions.any((s) => s.sessionId == id) != true) {
          return;
        }
        ref.read(currentSessionProvider.notifier).select(id);
        onClose();
      },
      onLongPress: (s) {
        final current = ref.read(drawerScopeProvider);
        if (ref.read(readListIdentityProvider) == identity &&
            current?.readOnly == false &&
            current!.sessions.any((row) => identical(row, s))) {
          _showActions(context, ref, s);
        }
      },
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, SessionSummary s) async {
    // Consent belongs to the host/generation present before the action sheet.
    final owner = captureSessionDeletionOwner(ref);
    try {
      await _showOwnedActions(context, ref, s, owner);
    } finally {
      owner?.close();
    }
  }


  Future<void> _showOwnedActions(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
    SessionDeletionOwner? deletionOwner,
  ) async {
    final title = sessionTitle(s);
    final workspaces = ref.read(workspacesProvider);
    final pinned = workspaces.pinnedSessionIds.contains(s.sessionId);
    final inFolder = ref.read(drawerViewProvider).folderOf.containsKey(s.sessionId);
    final action = await showAppSheet<String>(
      context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SheetHeader(title),
                SheetGroup(
                  children: [
                    // Pinning lives in the host's workspace registry.
                    if (workspaces.ready)
                      ListTile(
                        leading: Icon(pinned ? AppIcons.pinActive : AppIcons.pin),
                        title: Text(pinned ? context.l10n.shellUnpin : context.l10n.commonPin),
                        onTap: () => Navigator.pop(sheet, pinned ? 'unpin' : 'pin'),
                      ),
                    ListTile(
                      leading: const Icon(AppIcons.rename),
                      title: Text(context.l10n.commonRename),
                      onTap: () => Navigator.pop(sheet, 'rename'),
                    ),
                    ListTile(
                      leading: const Icon(AppIcons.moveToFolder),
                      title: Text(inFolder ? context.l10n.shellMoveToOtherFolder : context.l10n.shellMoveToFolder),
                      onTap: () => Navigator.pop(sheet, 'folder'),
                    ),
                    ListTile(
                      leading: const Icon(AppIcons.share),
                      title: Text(context.l10n.commonShare),
                      onTap: () => Navigator.pop(sheet, 'share'),
                    ),
                    ListTile(
                      leading: const Icon(AppIcons.multiSelect),
                      title: Text(context.l10n.shellMultiSelect),
                      onTap: () => Navigator.pop(sheet, 'select'),
                    ),
                    ListTile(
                      leading: const Icon(AppIcons.archive),
                      title: Text(context.l10n.shellArchive),
                      subtitle: Text(context.l10n.shellArchiveStopsTurn),
                      onTap: () => Navigator.pop(sheet, 'archive'),
                    ),
                    SessionDeleteTile(
                      ids: [s.sessionId],
                      owner: deletionOwner,
                      onTap: () {
                        if (deletionOwner?.isCurrent(ref) == true) Navigator.pop(sheet, 'delete');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (action) {
      case 'pin' || 'unpin':
        try {
          final notifier = ref.read(workspacesProvider.notifier);
          await (action == 'pin' ? notifier.pinSession(s.sessionId) : notifier.unpinSession(s.sessionId));
        } catch (_) {
          messenger?.showSnackBar(
            SnackBar(content: Text(action == 'pin' ? appL10n.shellPinFailed : appL10n.shellUnpinFailed)),
          );
        }
      case 'share':
        await shareConversation(context, s.sessionId);
      case 'folder':
        await moveToFolderFlow(context, ref, [s.sessionId]);
      case 'select':
        ref.read(drawerSelectionProvider.notifier).start(s.sessionId);
      case 'rename':
        final next = await _askTitle(context, s.title?.trim() ?? '');
        if (next == null || next.isEmpty || next == s.title) return;
        try {
          await ref.read(sessionsProvider.notifier).rename(s.sessionId, next);
        } catch (_) {
          messenger?.showSnackBar(SnackBar(content: Text(appL10n.shellRenameFailed)));
        }
      case 'delete':
        if (deletionOwner != null && deletionOwner.isCurrent(ref)) {
          await deleteSessionsFlow(context, ref, [s.sessionId], owner: deletionOwner);
        }
      case 'archive':
        unawaited(
          scheduleArchiveNotice(context, ref, [
            s.sessionId,
          ], s.running ? appL10n.shellChatStoppedArchived(title) : appL10n.shellChatArchived(title)),
        );
    }
  }

  Future<String?> _askTitle(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showAppDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.l10n.shellRenameChat),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(hintText: context.l10n.shellChatTitle, counterText: ''),
          onSubmitted: (v) => Navigator.pop(dialog, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

/// DS Bot's conversations as one row above the list: the glyph on the 20
/// text line, 「DS Bot」, then a breathing dot while a Bot works and the
/// unread count. Opens the Bot pages.
class DsBotDrawerRow extends ConsumerWidget {
  const DsBotDrawerRow({super.key, required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = ref.watch(dsBotInboxProvider.select((i) => i.total));
    final shape = Squircle.border(AppShape.md);
    return Semantics(
      button: true,
      label: [
        'DS Bot',
        if (running) l10n.shellCurrentlyRunning,
        if (unread > 0) l10n.shellUnreadCount(unread),
      ].join(l10n.shellSemanticsSeparator),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(AppIcons.bot, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DS Bot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (running) ...[const SizedBox(width: 10), const StatusDot(tone: StatusTone.busy, size: 7)],
                  if (unread > 0) ...[const SizedBox(width: 10), UnreadBadge(unread)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading: a few quiet placeholder rows on the same grid as the real ones,
/// breathing slowly (still under reduced motion).
class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: AppMotion.breath);
  late final Animation<double> _opacity = _breath.drive(
    Tween(begin: 0.55, end: 1.0).chain(CurveTween(curve: AppMotion.std)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _breath
        ..stop()
        ..value = 1;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.onSurface.withValues(alpha: scheme.brightness == Brightness.dark ? 0.09 : 0.07);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
    );
    const widths = [0.72, 0.5, 0.64, 0.42, 0.58];
    return Semantics(
      label: l10n.shellLoadingChats,
      child: FadeTransition(
        opacity: _opacity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final row = constraints.maxWidth - 40;
            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                Padding(padding: const EdgeInsets.only(top: 19, bottom: 9), child: bar(28, 8)),
                for (final w in widths)
                  SizedBox(
                    height: 44,
                    child: Align(alignment: Alignment.centerLeft, child: bar(row * w, 10)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keeps an empty view in the upper third of the list area.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: const Alignment(0, -0.4),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: child),
          ),
        ),
      ),
    );
  }
}

/// The selected workspace has no conversations yet.
class _WorkspaceEmptyState extends ConsumerWidget {
  const _WorkspaceEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Centered(
      child: EmptyView(
        compact: true,
        icon: AppIcons.folderOpen,
        title: l10n.shellWorkspaceNoChats,
        message: l10n.shellWorkspaceNewChatsHint,
        actionLabel: l10n.remoteWorkspaceAllChats,
        onAction: () => ref.read(workspacePrefsProvider.notifier).select(null),
      ),
    );
  }
}

/// No sessions: either the engine (or remote host) isn't up yet, or there
/// simply are none.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final host = ref.watch(activeHostProvider);
    if (!host.isLocal) return _RemoteEmptyState(host: host);
    final status = ref.watch(localRuntimeProvider.select((s) => s.status));
    if (EngineFailureCard.visibleFor(status)) {
      return const SingleChildScrollView(padding: EdgeInsets.fromLTRB(10, 8, 10, 16), child: EngineFailureCard());
    }
    final view = switch (status.phase) {
      RuntimePhase.running => EmptyView(
        compact: true,
        icon: AppIcons.chat,
        title: l10n.shellNoChatsYet,
        message: l10n.shellNewChatsHint,
      ),
      RuntimePhase.starting => EmptyView(
        compact: true,
        icon: AppIcons.loading,
        title: l10n.shellEngineStarting,
        message: l10n.shellChatsAfterStarting,
      ),
      RuntimePhase.installed || RuntimePhase.error => EmptyView(
        compact: true,
        icon: AppIcons.power,
        title: l10n.shellEngineNotRunning,
        message: l10n.shellChatsAfterStarting,
        actionLabel: l10n.shellStartEngine,
        onAction: () => unawaited(EngineControl.ensureStarted(ProviderScope.containerOf(context))),
      ),
      RuntimePhase.notInstalled when status.runtimeMissing => EmptyView(
        compact: true,
        icon: AppIcons.thisPhone,
        title: l10n.localEnvNotInstalled,
        actionLabel: l10n.phoneEngineInstallRuntime,
        onAction: () => unawaited(openLocalInstall(context)),
      ),
      _ => EmptyView(
        compact: true,
        icon: AppIcons.power,
        title: l10n.shellEngineNotRunning,
        message: l10n.shellEngineStatusHint,
      ),
    };
    return _Centered(child: view);
  }
}

/// Empty list on a remote host: connecting, failed (with the reason and a
/// retry), or connected with no conversations yet.
class _RemoteEmptyState extends ConsumerWidget {
  const _RemoteEmptyState({required this.host});

  final HostRef host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = ref.watch(hostNameProvider(host)) ?? l10n.commonRemoteHost;
    final status = ref.watch(hostLinkStatusProvider(host)).value ?? HostLinkStatus.idle;
    void retry() => ref.read(remoteConnectionProvider(host).notifier).retry();
    final view = switch (status.phase) {
      HostLinkPhase.connected => EmptyView(
        compact: true,
        icon: AppIcons.chat,
        title: l10n.shellNoChatsYet,
        message: l10n.shellNewChatsHint,
      ),
      HostLinkPhase.failed => EmptyView(
        compact: true,
        icon: AppIcons.disconnected,
        title: l10n.shellHostUnreachable(name),
        message: status.error?.message ?? l10n.commonConnectionFailed,
        actionLabel: status.error?.retryable ?? true ? l10n.commonRetry : null,
        onAction: retry,
      ),
      HostLinkPhase.reconnecting => EmptyView(
        compact: true,
        icon: AppIcons.reconnecting,
        title: l10n.shellHostReconnecting(name),
        message: status.error?.message,
        actionLabel: l10n.shellRetryNow,
        onAction: retry,
      ),
      _ => EmptyView(
        compact: true,
        icon: AppIcons.reconnecting,
        title: l10n.shellHostConnecting(name),
        message: status.step == null ? l10n.shellHostChatsAfterConnecting : '${status.step!.label}…',
      ),
    };
    return _Centered(child: view);
  }
}

/// The drawer's footer: 新对话 at the left, the settings key at the right.
///
/// ChatGPT's sidebar ends with two quiet keys rather than a host switcher, and
/// the engine's state has a better home (the header and the empty state). The
/// settings key is the official gear glyph; a long press goes straight to
/// settings search.
class DrawerBottomBar extends StatelessWidget {
  const DrawerBottomBar({
    super.key,
    required this.onNewChat,
    required this.onSettings,
    this.onSettingsHold,
  });

  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  /// ⚙ held down: straight to settings search.
  final VoidCallback? onSettingsHold;

  /// The round keys, and the bar's height beside them.
  static const keySize = 44.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = ChatGptShellColors.of(context);
    return Padding(
      // Same 10 / 20 grid as the rows above: the new-chat key on the 10 line,
      // the settings key ending on the 10 line.
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // The round compose key, exactly as ChatGPT draws it: a solid
              // primary circle holding the glyph, with the words in the label.
              child: NewChatButton(onTap: onNewChat),
            ),
          ),
          const SizedBox(width: 8),
          // The official gear, so the app's own settings glyph stays out of the
          // drawer's chrome (it is what every other entry here uses).
          Semantics(
            button: true,
            label: l10n.commonSettings,
            onTap: onSettings,
            onLongPress: onSettingsHold,
            excludeSemantics: true,
            child: InkResponse(
              key: const ValueKey('drawer-settings'),
              onTap: onSettings,
              onLongPress: onSettingsHold,
              radius: keySize / 2,
              child: SizedBox.square(
                dimension: keySize,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: shell.composerBorder, width: 1),
                    ),
                    child: SizedBox.square(
                      dimension: 32,
                      child: ChatGptGearIcon(size: 19, color: shell.secondaryText),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// 抽屉顶部的「Agent 体征」条：这台 Agent 现在是什么状态、有几样本事。
///
/// 为什么要有这一条：ChatGPT 的侧栏只有会话列表，它不需要告诉用户「模型在不在」。
/// PlugHarness 是个宿主——用户得先知道引擎起没起、插件装没装，才谈得上「让 Agent 干活」。
/// 把这些塞进侧栏能把「去设置页查状态」的往返省掉。
///
/// 三条克制规则：
/// - **没有信息就不占位**：断线、未安装、插件清单未就绪时整条收起，不留空壳；
/// - **一行说完**：最多两个分段（引擎 / 插件），再多就换行而不是挤；
/// - **可点即去**：点它打开引擎页，与 `SafeModeBanner` 的落点一致。
///
/// **这一条现在没有接线**：2026-11 的侧栏改版把它从固定区挪走后没有再放回
/// 滚动体，所以它当前不被任何地方构造。保留是因为「引擎起没起」在窄屏侧栏
/// 仍然有信息价值，但**不要以为它在侧栏上看得见** —— 要恢复就得把它放进
/// `_DrawerConversationSliver` 上方的 sliver 里（并配几何测试）。
class _AgentVitals extends ConsumerWidget {
  const _AgentVitals({required this.padding});

  final EdgeInsets padding;

  /// 分段之间的点。
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(localRuntimeProvider.select((s) => s.status.phase));
    final plugins = ref.watch(cordisInventoryProvider).value;

    final segments = <String>[];
    // 引擎：只说「在跑」和「还没起来」，busy 的中间态不在这里播报（顶栏已有）。
    if (phase == RuntimePhase.running) {
      segments.add(context.l10n.shellVitalsEngineRunning);
    } else if (phase == RuntimePhase.notInstalled) {
      segments.add(context.l10n.shellVitalsEngineMissing);
    } else if (phase == RuntimePhase.error) {
      segments.add(context.l10n.shellVitalsEngineError);
    }
    final count = plugins?.length;
    if (count != null && count > 0) {
      segments.add(context.l10n.shellVitalsPlugins(count));
    }
    if (segments.isEmpty) return const SizedBox.shrink();

    final shell = ChatGptShellColors.of(context);
    final theme = Theme.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          if (i > 0)
            Text('·', style: theme.textTheme.bodySmall?.copyWith(color: shell.tertiaryText))
          else
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: phase == RuntimePhase.running ? DshColors.of(context).success : shell.tertiaryText,
              ),
            ),
          if (i > 0) const SizedBox(width: _gap),
          Flexible(
            child: Text(
              segments[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: shell.tertiaryText),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: segments.join('，'),
        child: Pressable(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EngineScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Align(alignment: AlignmentDirectional.centerStart, child: row),
          ),
        ),
      ),
    );
  }
}
