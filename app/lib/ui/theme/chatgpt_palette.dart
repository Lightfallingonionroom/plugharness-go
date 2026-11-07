// The neutral palette of the ChatGPT-style shell: near-white / near-black
// surfaces with one accent reserved for the one primary action (新对话).
//
// Deliberately not a ColorScheme.fromSeed result: a seeded scheme tints every
// neutral, which is exactly what makes a chat UI feel unlike a document. The
// app's accent colour still comes from DshPalette; this file only describes
// the two flat surfaces the shell paints (page, sidebar) and the soft fills
// used by rows, so light and dark stay legible at the same contrast.

import 'package:flutter/material.dart';

import 'accent.dart';
import 'surfaces.dart';

/// Flat surfaces and quiet fills for the shell.
@immutable
class ChatGptShellColors extends ThemeExtension<ChatGptShellColors> {
  const ChatGptShellColors({
    required this.page,
    required this.sidebar,
    required this.composer,
    required this.composerBorder,
    required this.rowHover,
    required this.rowSelected,
    required this.divider,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.userBubble,
    required this.onUserBubble,
  });

  /// Behind the conversation.
  final Color page;

  /// Behind the conversation list.
  final Color sidebar;

  /// The composer's solid field.
  final Color composer;

  /// Its hairline: the composer has no shadow of its own.
  final Color composerBorder;

  /// A conversation row under the finger (Material hover / pressed).
  final Color rowHover;

  /// The open conversation's row.
  final Color rowSelected;

  final Color divider;

  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;

  /// 新对话: the one filled element in the shell.
  final Color primaryAction;
  final Color onPrimaryAction;
  /// The sent message: a filled, right-aligned bubble like ChatGPT's.
  final Color userBubble;
  final Color onUserBubble;

  /// True when the shell paints light-on-dark.
  bool get isDark => page.computeLuminance() < 0.5;

  static ChatGptShellColors of(BuildContext context) => Theme.of(context).extension<ChatGptShellColors>()!;

  /// A bar button on the flat header: no fill, no border, no shadow. Press
  /// feedback comes from the InkWell inside [GlassSurface].
  GlassStyle get flatChrome => const GlassStyle(
    fill: Colors.transparent,
    fallbackFill: Colors.transparent,
    hairline: Colors.transparent,
    rim: Colors.transparent,
  );

  /// The composer: a solid field with a hairline, like a text area rather
  /// than a floating glass capsule.
  GlassStyle get composerGlass => GlassStyle(
    fill: composer,
    fallbackFill: composer,
    hairline: composerBorder,
    rim: Colors.transparent,
    hairlineWidth: 1,
  );

  /// The conversation list: one flat panel, distinct from the page by tone
  /// only. No blur: the drawer slides over the chat, and a moving blur is
  /// the most expensive thing this screen could do.
  GlassStyle get sidebarGlass => GlassStyle(
    fill: sidebar,
    fallbackFill: sidebar,
    hairline: divider,
    rim: Colors.transparent,
    hairlineWidth: 0,
  );

  /// Light: page near-white; the sidebar is the same family one step down.
  /// Values from the official `@openai/apps-sdk-ui` tokens (docs/openai-sdk-ui-spec.md):
  /// surface #ffffff, surface-secondary #f9f9f9, text #0d0d0d / #5d5d5d / #8f8f8f.
  /// The primary action is a near-black solid, not a coloured fill: OpenAI keeps
  /// blue for the focus ring and links only (--color-ring / --link-primary).
  /// [accent] is kept for the caller's convenience and deliberately unused.
  factory ChatGptShellColors.light(AppAccent accent) => ChatGptShellColors(
    page: const Color(0xFFFCFCFC),
    sidebar: const Color(0xFFF4F4F4),
    composer: const Color(0xFFFFFFFF),
    composerBorder: const Color(0xFFDCDCDC),
    rowHover: const Color(0xFFECECEC),
    rowSelected: const Color(0xFFE8E8E8),
    divider: const Color(0xFFE5E5E5),
    primaryText: const Color(0xFF0D0D0D),
    secondaryText: const Color(0xFF5D5D5D),
    tertiaryText: const Color(0xFF8F8F8F),
    // --color-background-primary-solid (light) = gray-900.
    primaryAction: const Color(0xFF181818),
    onPrimaryAction: const Color(0xFFFFFFFF),
    // --user-message-background-color: alpha 5% over the surface, not a fill colour.
    userBubble: const Color(0x0D0D0D0D),
    onUserBubble: const Color(0xFF0D0D0D),
  );

  /// Dark: page #212121 (SDK gray-200 / MUI's measured `bg`), sidebar #171717,
  /// composer and row fills #2f2f2f, borders #424242 — the values the official
  /// ChatGPT-style layout uses. See docs/openai-sdk-ui-spec.md and
  /// docs/external-refs-summary.md §2.
  factory ChatGptShellColors.dark(AppAccent accent) => ChatGptShellColors(
    page: const Color(0xFF212121),
    sidebar: const Color(0xFF171717),
    composer: const Color(0xFF2F2F2F),
    composerBorder: const Color(0xFF424242),
    rowHover: const Color(0xFF2F2F2F),
    rowSelected: const Color(0xFF2F2F2F),
    divider: const Color(0xFF2F2F2F),
    primaryText: const Color(0xFFECECEC),
    secondaryText: const Color(0xFFB4B4B4),
    tertiaryText: const Color(0xFF8E8E8E),
    // --color-background-primary-solid (dark) = gray-950: near-white.
    primaryAction: const Color(0xFFF3F3F3),
    onPrimaryAction: const Color(0xFF0D0D0D),
    // alpha 8% white over the page, the official user-message fill.
    userBubble: const Color(0x14FFFFFF),
    onUserBubble: const Color(0xFFECECEC),
  );

  @override
  ChatGptShellColors copyWith({
    Color? page,
    Color? sidebar,
    Color? composer,
    Color? composerBorder,
    Color? rowHover,
    Color? rowSelected,
    Color? divider,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? userBubble,
    Color? onUserBubble,
  }) => ChatGptShellColors(
    page: page ?? this.page,
    sidebar: sidebar ?? this.sidebar,
    composer: composer ?? this.composer,
    composerBorder: composerBorder ?? this.composerBorder,
    rowHover: rowHover ?? this.rowHover,
    rowSelected: rowSelected ?? this.rowSelected,
    divider: divider ?? this.divider,
    primaryText: primaryText ?? this.primaryText,
    secondaryText: secondaryText ?? this.secondaryText,
    tertiaryText: tertiaryText ?? this.tertiaryText,
    primaryAction: primaryAction ?? this.primaryAction,
    onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
    userBubble: userBubble ?? this.userBubble,
    onUserBubble: onUserBubble ?? this.onUserBubble,
  );

  @override
  ChatGptShellColors lerp(ChatGptShellColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChatGptShellColors(
      page: mix(page, other.page),
      sidebar: mix(sidebar, other.sidebar),
      composer: mix(composer, other.composer),
      composerBorder: mix(composerBorder, other.composerBorder),
      rowHover: mix(rowHover, other.rowHover),
      rowSelected: mix(rowSelected, other.rowSelected),
      divider: mix(divider, other.divider),
      primaryText: mix(primaryText, other.primaryText),
      secondaryText: mix(secondaryText, other.secondaryText),
      tertiaryText: mix(tertiaryText, other.tertiaryText),
      primaryAction: mix(primaryAction, other.primaryAction),
      onPrimaryAction: mix(onPrimaryAction, other.onPrimaryAction),
      userBubble: mix(userBubble, other.userBubble),
      onUserBubble: mix(onUserBubble, other.onUserBubble),
    );
  }
}