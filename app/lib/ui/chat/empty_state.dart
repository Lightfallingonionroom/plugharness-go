import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/fade_in.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'empty_actions.dart';
import 'widgets/whale_tail.dart';

// 建议卡（`ChatSuggestion` / `defaultSuggestions`）与底部小技巧
// （`defaultTips`）的定义仍在本文件里，但**空态已经不再画它们**（2026-11 按
// 用户要求删除）。保留定义是因为：
//   - `defaultTips()` 的文案键还在 l10n 里，删文案要同步删 ARB；
//   - 有几条测试仍在断言这些文案本身。
// 要彻底移除需要一轮「删定义 + 删 ARB + 删测试」，不在本次 UI 改版范围内。
/// 一条建议:一枚带色底的线性小图标 + 标题 + 一行说明,点了把 [prompt] 填进输入条。
///
/// 默认的四条是 PlugHarness 自己的能力入口(手机操控 / 插件 / 工作区 / 日程),
/// 不是通用开发任务——新对话页应当先说清「这个 App 能替你做什么」。
class ChatSuggestion {
  const ChatSuggestion(this.icon, String label, String prompt, {this._detail, this.tint = SuggestionTint.blue})
    : _label = label,
      _prompt = prompt,
      _defaultIndex = null;

  const ChatSuggestion._default(this.icon, this._defaultIndex, this.tint) : _label = null, _prompt = null, _detail = null;

  final IconData icon;
  final SuggestionTint tint;
  final String? _label;
  final String? _prompt;
  final String? _detail;
  final int? _defaultIndex;

  String get label =>
      _label ??
      switch (_defaultIndex) {
        0 => appL10n.viewSuggestPhone,
        1 => appL10n.viewSuggestPlugin,
        2 => appL10n.viewSuggestWorkspace,
        _ => appL10n.viewSuggestSchedule,
      };

  /// One line under the title: what the suggestion will do.
  String? get detail => _defaultIndex == null
      ? _detail
      : switch (_defaultIndex) {
          0 => appL10n.viewSuggestPhoneHint,
          1 => appL10n.viewSuggestPluginHint,
          2 => appL10n.viewSuggestWorkspaceHint,
          _ => appL10n.viewSuggestScheduleHint,
        };

  String get prompt =>
      _prompt ??
      switch (_defaultIndex) {
        0 => appL10n.viewSuggestPhonePrompt,
        1 => appL10n.viewSuggestPluginPrompt,
        2 => appL10n.viewSuggestWorkspacePrompt,
        _ => appL10n.viewSuggestSchedulePrompt,
      };
}

const defaultSuggestions = <ChatSuggestion>[
  ChatSuggestion._default(AppIcons.phoneControl, 0, SuggestionTint.teal),
  ChatSuggestion._default(AppIcons.plugin, 1, SuggestionTint.violet),
  ChatSuggestion._default(AppIcons.folderOpen, 2, SuggestionTint.amber),
  ChatSuggestion._default(AppIcons.scheduled, 3, SuggestionTint.blue),
];

/// Tips about using DSH Go, one at a time under the suggestions. Each names
/// a gesture or entry the app really has (see the handlers it describes).
List<String> defaultTips() => [
  appL10n.viewTipSteer,
  appL10n.viewTipMidRun,
  appL10n.viewTipSlash,
  appL10n.viewTipMention,
  appL10n.viewTipReplyMenu,
  appL10n.viewTipEditResend,
  appL10n.viewTipQuote,
  appL10n.viewTipTitleDetails,
  appL10n.viewTipContextRing,
  appL10n.viewTipDrawerMenu,
  appL10n.viewTipSearch,
  appL10n.viewTipSettingsSearch,
  appL10n.viewTipModelHere,
  appL10n.viewTipQuickPanel,
  appL10n.viewTipFolderNewChat,
  appL10n.viewTipSwitchHost,
  appL10n.viewTipPasteImage,
  appL10n.viewTipLauncher,
  appL10n.viewTipPetBubble,
  appL10n.viewTipPetPlay,
  appL10n.viewTipActivityStrip,
  appL10n.viewTipImageZoom,
  appL10n.viewTipQueuedRecall,
  appL10n.viewTipKeyboard,
  appL10n.viewTipShareIn,
  appL10n.viewTipShareSelect,
  appL10n.viewTipChartDrag,
  appL10n.viewTipCopyPath,
  appL10n.viewTipCompanion,
  appL10n.viewTipAnswerInline,
  appL10n.viewTipWallpaper,
];

/// 当前时间的来源(测试里固定它,让问候语可复现)。
@visibleForTesting
DateTime Function() chatClock = DateTime.now;

/// 问候语:按本地时间。
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return appL10n.viewGreetingMorning;
  if (h >= 11 && h < 13) return appL10n.viewGreetingNoon;
  if (h >= 13 && h < 18) return appL10n.viewGreetingAfternoon;
  if (h >= 18 && h < 23) return appL10n.viewGreetingEvening;
  return appL10n.viewGreetingNight;
}

/// 新对话的空状态:ChatGPT 式**一句大标题居中偏上**,下面是一条短副标题和
/// 少量起点。没有插画、没有鲸尾:输入框才是这一屏唯一的主角。
///
/// ```
///                你想做点什么？
///
///          ( ▢ 在「dsh-app」中 ⌄ )
/// ```
///
/// 左右与顶栏、输入条一样离屏幕 12,宽屏时与输入条同宽居中;第一次出现时
/// 由上到下依次淡入。连不上引擎时建议、选项和小技巧都收起,只留「重新连接」。
///
/// **建议卡和小技巧已按用户要求删除**（2026-11）：空态只留鲸尾 + 时段问候
/// + 模式/权限两行。它们是 2026-10 加的，和 ChatGPT 的空态结构（一句大标题
/// + 输入框）不是一家；留着一屏反而更像「套壳的另一个产品」。
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.connected,
    required this.onSuggestion,
    this.connecting = false,
    this.starting = false,
    this.tidying = false,
    this.onReconnect,
    this.idle,
    this.now,
    this.workspace,
    this.onWorkspace,
    this.options,
  });

  final bool connected;
  final bool connecting;

  /// The on-device engine is booting.
  final bool starting;

  /// Booting includes the one-time tidy of plugin files (RuntimeStatus.tidyingFiles).
  final bool tidying;

  /// The engine could not be reached: the one primary pill, 「重新连接」,
  /// where the workspace chip goes; the suggestions fold away.
  final VoidCallback? onReconnect;

  /// 本机 is down and won't come up by itself (not installed, or stopped
  /// with 打开 App 时自动启动 off): the subtitle says so and the one primary
  /// pill fixes it (「安装运行环境」 / 「启动引擎」).
  final ChatIdleAction? idle;
  final ValueChanged<ChatSuggestion> onSuggestion;

  /// The workspace the new conversation starts in (null: the default).
  final String? workspace;

  /// Switches [workspace].
  final VoidCallback? onWorkspace;

  /// The new conversation's options (folder, preset, permissions), one row of
  /// quiet chips under the workspace chip. Shown only while connected.
  final Widget? options;

  /// 测试注入;默认取当前时间。
  final DateTime? now;

  /// Same side margin and width cap as the header pills and the composer.
  static const sideMargin = AppSpace.floatInset;
  static const maxWidth = AppSpace.floatingWidth;

  /// Subtitle → the pill or chip under it.
  static const slotGap = 12.0;

  /// The workspace chip → the options row.
  static const optionsGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final retry = connected ? null : onReconnect;
    final idle = connected || retry != null ? null : this.idle;
    // Connected, the title is the whole line: a subtitle here only repeated
    // it ("有什么可以帮你？" over "今天想做点什么？"). Everything else still says
    // what is going on, and why the composer will not send.
    final subtitle = connected
        ? null
        : retry != null
        ? l10n.commonEngineUnreachable
        : idle != null
        ? idle.message
        : starting
        ? (tidying ? l10n.phoneEngineTidyingFilesEllipsis : l10n.viewEmptyStarting)
        : connecting
        ? l10n.viewEmptyConnecting
        : l10n.viewEmptyDisconnected;

    // Fixed slots, not a running counter: the subtitle comes and goes with
    // the connection, and a counter would shift every later fade-in with it.
    var order = 0;
    Widget enter(Widget child) => FadeSlideIn(index: order++, child: child);

    // 品牌形 + 时段问候。设计规范 page-design.md §3 要求「鲸尾品牌形 +
    // 按时段的问候」，此处恢复——上一轮照抄 ChatGPT 时连品牌一起抹掉了。
    // 鲸尾用静止帧（still），不带计时器：这一屏不该有一只在动的东西和输入框抢注意力。
    final whaleFade = enter(
      _EmptyWhale(connected: connected),
    );
    final titleFade = enter(
      Text(
        connected ? greetingFor(chatClock()) : l10n.viewEmptyTitle,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: ChatGptShellColors.of(context).primaryText,
        ),
      ),
    );
    final subtitleFade = subtitle == null
        ? null
        : enter(
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.quick),
              child: Text(
                subtitle,
                key: ValueKey(subtitle),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: ChatGptShellColors.of(context).secondaryText,
                ),
              ),
            ),
          );

    // One slot under the subtitle: the primary pill or the workspace chip,
    // the same height, swapped in place.
    final Widget? slot = retry != null
        ? EmptyPrimaryPill(key: const ValueKey('reconnect'), label: l10n.viewEmptyReconnect, onTap: retry)
        : idle != null
        ? EmptyPrimaryPill(key: ValueKey(idle.label), label: idle.label, onTap: idle.onTap)
        : workspace != null && connected
        ? ConstrainedBox(
            key: const ValueKey('workspace'),
            constraints: const BoxConstraints(maxWidth: 280),
            child: QuietChip(
              icon: AppIcons.workspace,
              label: l10n.viewEmptyWorkspace(workspace!),
              trailing: onWorkspace == null ? null : AppIcons.expand,
              onTap: onWorkspace,
              onTapHint: l10n.viewEmptySwitchWorkspace,
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: sideMargin),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部是品牌形 + 时段问候:一屏只说一件事,输入框仍是唯一的主角。
              whaleFade,
              const SizedBox(height: 16),
              titleFade,
              if (subtitleFade != null) ...[const SizedBox(height: 8), subtitleFade],
              if (slot != null) ...[
                const SizedBox(height: slotGap),
                enter(
                  Center(
                    child: AnimatedSwitcher(duration: AppMotion.of(context, AppMotion.quick), child: slot),
                  ),
                ),
              ],
              if (connected && options != null) ...[
                const SizedBox(height: optionsGap),
                enter(Center(child: options!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [ChatEmptyState.idle]: what the subtitle says and the pill under it.
class ChatIdleAction {
  const ChatIdleAction({required this.message, required this.label, required this.onTap});

  final String message;
  final String label;
  final VoidCallback onTap;
}

/// 空态顶部的品牌形:一尾静止的鲸,很淡。
///
/// 三条克制规则,避免它变成一屏插画:
/// - **静止帧**([WhaleTail.still]):不跑计时器,不与输入框抢注意力;
/// - **半透明**(0.5):它是水印,不是主体;
/// - **矮横屏不出现**:高 < 480 时纵向本来就不够,让位给建议卡。
class _EmptyWhale extends StatelessWidget {
  const _EmptyWhale({required this.connected});

  /// 连不上引擎时品牌形也收起来:那一屏只该有「重新连接」。
  final bool connected;

  /// 鲸尾帧的 5:4 比例,宽由高推出来。
  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    if (!connected) return const SizedBox.shrink();
    // 矮横屏(手机横放,915×412 这类)纵向空间紧张:品牌形让位。
    final compactHeight = MediaQuery.sizeOf(context).height < 480;
    if (compactHeight) return const SizedBox.shrink();
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: WhaleTail(
          color: whaleColorFor(Theme.of(context).brightness),
          height: height,
          still: true,
        ),
      ),
    );
  }
}
