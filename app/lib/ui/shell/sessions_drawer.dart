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
import '../../runtime/local_footprint.dart';
import '../../state/bots_state.dart';
import '../../state/connection_state.dart';
import '../../state/engine_control.dart';
import '../../state/hosts_state.dart';
import '../../state/drawer_view_state.dart';
import '../../state/session_attention_state.dart';
import '../../state/session_deletion_state.dart';
import '../../state/sessions_state.dart';
import '../../state/read_list_identity.dart';
import '../../state/quick_panel_state.dart';
import '../../state/workspaces_state.dart';
import '../bots/bots_page.dart' show BotsPage, UnreadBadge;
import '../chat/media/media_format.dart' show chatTitleShown;
import '../common/app_dialog.dart';
import '../common/app_sheet.dart';
import '../common/empty_view.dart';
import '../common/pressable.dart';
import '../common/smooth_size.dart';
import '../common/read_list_status.dart';
import '../common/status_dot.dart';
import '../onboarding/local_install.dart';
import '../remote/host_status.dart';
import '../remote/host_switcher.dart' show showHostSheet;
import '../remote/network_details_sheet.dart' show showRemoteNetworkDetails;
import '../safe_mode/engine_failure_card.dart';
import '../safe_mode/safe_mode_banner.dart';
import '../share/share_entry.dart';
import '../theme/app_icons.dart';
import '../engine/engine_screen.dart';
import '../theme/theme.dart';
import '../web/mode_home.dart';
import '../workspace/workspace_switcher.dart';
import '../workspace/workspaces_page.dart';
import 'brand_mark.dart';
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

/// The sessions drawer: brand and "新对话" on top, search, the workspace
/// switcher with the list's options, the status filters, the active host's
/// conversations (pinned, folders, then by day), and an identity bar at the
/// bottom (the host, 网页版, 设置). In multi-select the brand row and the
/// identity bar give way to the selection header and its action bar.
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
    final quickItems = ref.watch(quickPanelProvider.select((p) => p.items));
    // Pinned above the scroll body: the brand row and the search field. ChatGPT
    // keeps exactly these two in place while everything below them scrolls.
    final pinned = <Widget>[
      AnimatedSwitcher(
        duration: quick,
        child: selecting
            ? DrawerSelectionHeader(key: const ValueKey('selecting'), now: now)
            : Padding(
                key: const ValueKey('brand'),
                // The lockup on the rows' 20 line, the action ending on the
                // 10 line; the same 14 / 10 box as [DrawerSelectionHeader],
                // so 完成 lands exactly where 新对话 was.
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                child: Row(
                  children: [
                    // On a narrow drawer with large text the lockup gives
                    // way a little rather than the keys.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BrandLockup(height: 19, label: 'PlugHarness'),
                        ),
                      ),
                    ),
                    const WebModeKey(tier: GlassTier.pill),
                    const SizedBox(width: 8),
                    NewChatButton(onTap: newChat),
                  ],
                ),
              ),
      ),
      SafeModeBanner(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        onDetails: () => onOpen(DrawerDestination.engine),
      ),
      // PlugHarness 的产品身份：这台 Agent 现在能做什么。
      // ChatGPT 的侧栏只有会话；我们的侧栏要先说清「谁在干活、有几样本事」。
      const _AgentVitals(padding: EdgeInsets.fromLTRB(10, 0, 10, 6)),
      SessionSearchBar(onClose: onClose),
    ];
    // Scrolls with the conversations: the feature rows, their section labels
    // and the filters. This is the part the one-scroll-body rule is about.
    final top = <Widget>[
      // ChatGPT splits its one column into labelled sections. Ours: the
      // app's rooms first, then the conversations themselves.
      _sectionLabel(context, l10n.searchFeatures),
      // The quick panel's destinations live here now, where ChatGPT keeps
      // them: one column that holds both the app's rooms and its
      // conversations, instead of a second panel sliding in from the right.
      // Same rows, same keys — only the place they are drawn.
      if (quickItems.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final destination in quickItems)
                QuickPanelRow(destination: destination, onTap: () => onOpen(destination)),
            ],
          ),
        ),
      // Rooms ChatGPT has but we route through pages we already own.
      for (final destination in const [
        DrawerDestination.web,
        DrawerDestination.remote,
        DrawerDestination.features,
      ])
        if (!quickItems.contains(destination))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: QuickPanelRow(destination: destination, onTap: () => onOpen(destination)),
          ),
      _sectionLabel(context, l10n.chatChat),
      // The workspace switcher (once the host's workspace list has
      // arrived) and the list's options, then the status filters.
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
    ];
    final list = _EdgeFade(
      child: _SessionList(onClose: onClose, now: now, header: top),
    );

    const radius = BorderRadius.only(topRight: Radius.circular(AppShape.xl), bottomRight: Radius.circular(AppShape.xl));
    final content = Material(
      color: shell.sidebar,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned: only the brand row and the search field. ChatGPT keeps
            // exactly these two in place while everything below them scrolls.
            ...pinned,
            // Everything else is one scroll body: the app's rooms, the workspace
            // row, the filters and the conversations move together, the way the
            // real ChatGPT sidebar does. They are handed to the list below as its
            // header so a single controller drives the whole column.
            Expanded(child: list),
            // No wide filled 新对话 pill down here: ChatGPT keeps a single round
            // compose key in the brand row above, and the bottom of its sidebar
            // is the account row. Two competing "new chat" affordances was one
            // of the things that made this drawer read as a different product.
            // The action bar lies exactly over the identity bar, which
            // keeps its size while hidden: same height at any text size.
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
                        child: IdentityBar(
                          onHost: () => showHostSheet(context, onManage: () => onOpen(DrawerDestination.remote)),
                          onLocalDetails: () => onOpen(DrawerDestination.engine),
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

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.onClose, this.now, this.header});

  final VoidCallback onClose;
  final DateTime? now;

  /// Rows drawn above the conversations, inside the same scroll body: the app's
  /// rooms, the workspace switcher and the filter bar. One controller, so they
  /// travel with the list instead of staying pinned.
  final List<Widget>? header;

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
        return _withHeader(context, const _EmptyState());
      }
      if (sessions.hasError) {
        return _withHeader(
          context,
          _Centered(
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
      return _withHeader(context, const _SkeletonList());
    }
    // DS Bot's conversations (its Bots' chats, groups, members' sessions)
    // fold into one row that opens the Bot pages.
    final botReady = ref.watch(dsBotProvider.select((s) => s.ready));
    final showBots = scope.bots.isNotEmpty || (workspace == null && botReady);
    if (scope.sessions.isEmpty && !showBots && ref.watch(drawerViewProvider).folders.isEmpty) {
      if (scope.readOnly) return _withHeader(context, _Centered(child: Text(readListStatusText(scope.status))));
      return _withHeader(context, workspace == null ? const _EmptyState() : const _WorkspaceEmptyState());
    }
    return DrawerConversationList(
      now: now,
      onNewChat: onClose,
      readOnly: scope.readOnly,
      header: header,
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

  /// A non-list state (empty / error / loading) with the drawer's control rows
  /// still above it and still scrolling with it, so 插件 and 设置 stay reachable
  /// on a fresh host. Without this the header would vanish whenever the
  /// conversation list has nothing to draw.
  Widget _withHeader(BuildContext context, Widget body) {
    final headerRows = header;
    if (headerRows == null || headerRows.isEmpty) return body;
    // hasScrollBody: true keeps the body inside a bounded box and hands it the
    // viewport height, which is what the _Centered states (a SingleChildScrollView
    // with a minHeight) need; false would give them an unbounded height.
    return CustomScrollView(
      physics: AppMotion.scrollPhysics(context),
      slivers: [
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: headerRows),
        ),
        SliverFillRemaining(hasScrollBody: true, child: body),
      ],
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

/// The drawer's footer: the host icon opens its details; the name and dropdown
/// switch hosts. 设置 follows as a round key.
class IdentityBar extends ConsumerWidget {
  const IdentityBar({
    super.key,
    required this.onHost,
    required this.onSettings,
    this.onSettingsHold,
    this.onLocalDetails,
  });
  final VoidCallback onHost;
  /// Local hosts have engine details, not a remote network path.
  final VoidCallback? onLocalDetails;
  final VoidCallback onSettings;

  /// ⚙ held down: straight to settings search.
  final VoidCallback? onSettingsHold;

  /// The round keys, and the host pill's height beside them.
  static const keySize = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final host = ref.watch(activeHostProvider);
    final name = ref.watch(hostNameProvider(host)) ?? (host.isLocal ? l10n.commonThisPhone : l10n.commonRemoteHost);
    final view = watchHostStatus(ref, host);
    final link = host.kind == HostKind.relay ? ref.watch(hostLinkStatusProvider(host)).value : null;
    final path = link?.isConnected == true ? link?.network?.path ?? link?.path : null;
    final statusLabel = path == null ? view.label : path.label;
    final tint = hostKindTint(host.kind);
    return Padding(
      // Same 10 / 20 grid as the rows above: the highlight's edge at 10, the
      // avatar on the 20 text line, the last button's edge at 10. The host
      // pill is as tall as the round keys beside it (44; taller only for
      // large text).
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 13),
      child: Row(
        children: [
          Expanded(
            child: Row(
              key: const ValueKey('identity-host-controls'),
              children: [
                const SizedBox(width: 6),
                IconButton(
                  key: const ValueKey('identity-host-details'),
                  tooltip: host.isLocal ? l10n.phoneEngineTitle : l10n.remoteNetworkDetails,
                  onPressed: host.isLocal ? onLocalDetails : () => showRemoteNetworkDetails(context, host),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints.tightFor(width: keySize, height: keySize),
                  style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: DecoratedBox(
                    decoration: ShapeDecoration(color: colors.identity[tint], shape: const CircleBorder()),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(hostKindIcon(host.kind), size: 19, color: colors.onIdentity[tint]),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.shellCurrentHostLabel(name, statusLabel),
                    onTap: onHost,
                    excludeSemantics: true,
                    child: InkWell(
                      key: const ValueKey('identity-host-switcher'),
                      onTap: onHost,
                      customBorder: Squircle.border(AppShape.md),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: IdentityBar.keySize),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusDot(tone: view.tone, size: 6),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: AnimatedSwitcher(
                                            duration: AppMotion.of(context, AppMotion.quick),
                                            layoutBuilder: (current, previous) => Stack(
                                              alignment: Alignment.centerLeft,
                                              children: [...previous, ?current],
                                            ),
                                            child: Text(
                                              statusLabel,
                                              key: ValueKey(statusLabel),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppType.tabular(
                                                theme.textTheme.bodySmall!.copyWith(color: colors.textTertiary),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(AppIcons.dropdown, size: 18, color: colors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Account avatar: the way into settings. ChatGPT's sidebar ends with
          // a round account picture, not a gear; a settings placeholder stands
          // in until the app has real avatars (the user asked for exactly this).
          // Single-colour line glyph on a hairline ring — no tinted disc, which
          // is what made the old footer read as a different product.
          _DrawerAvatar(
            onTap: onSettings,
            onLongPress: onSettingsHold,
            tooltip: l10n.commonSettings,
          ),
        ],
      ),
    );
  }
}

/// The drawer's account entry: a 44dp tap target holding a 32dp circle with a
/// hairline ring and the `circle_person` glyph. No colour: the identity hues
/// belong to host kinds, not to the account.
class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({required this.onTap, required this.tooltip, this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String tooltip;

  static const _ring = 32.0;

  @override
  Widget build(BuildContext context) {
    final shell = ChatGptShellColors.of(context);
    // No [Tooltip] wrapper: the avatar's Semantics already carries the label,
    // and a Tooltip would add a second node with the same text (widget tests
    // and screen readers would both see two "设置" targets).
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: IdentityBar.keySize / 2,
        child: SizedBox.square(
          dimension: IdentityBar.keySize,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: shell.composerBorder, width: 1),
              ),
              child: SizedBox.square(
                dimension: _ring,
                child: Icon(
                  AppIcons.avatar,
                  size: 20,
                  color: shell.secondaryText,
                ),
              ),
            ),
          ),
        ),
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
