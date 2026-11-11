# `@` 提及扩展：参考仓库调研与本仓库实现方案

> 用户次要需求：「Operit 有 `@` 输入框快捷方式，可以 @ 工作区文件或者
> @ mcp／skill／技能／插件／等等，你给我也做上」。
> 2026-11-11 读三个参考仓库 + 两个 npm 包后写。

## 一、参考了什么

| 仓库 | 星 | 说明 |
|---|---|---|
| `FSMargoo/dsh-at-file`（README 里 `omdsh-dev/dsh-at-file` 重定向到此） | 569 | Codex 式 `@file` 提及，工作区文件搜索 + 附加 |
| `Chael-Chael/dsh-reference-anything` | 27 | **「一个 @ 引用万物」**：Commands / Skills / 文件 / DSH 会话 / 本地 Agent / 外部对话 / 网盘 / 本地插件 |
| `liznee/dsh-file-resource` | 1 | `＋` 菜单顶部加 attach，本地文件资源 |
| npm `@hucj/dsh-file-mention` 0.1.16 | — | 纯前端 @file picker（git-tracked 文件） |
| npm `@ohoyo/dsh-file-mention` 0.1.4 | — | profile bundle：host 插件 + web client |

## 二、最关键的一条结论（来自 `dsh-reference-anything/src/client/source.ts`）

它把不同来源统一进**一个 `@` 菜单**，但**选中后按来源插入不同文本**，
并没有扩展 DSH 的引用协议：

| 来源 | 数据来源 | 选中后插入 |
|---|---|---|
| Commands | `ctx.remote.commands.list(sessionId)`（DSH 原生接口） | `/name` |
| Skills | `ctx.remote.skills.list({sessionId})`（DSH 原生 `skills/list`） | `/name ` |
| 文件 | DSH 原生 `fileReferences/list` | `@path` / `@[label](dsh-ref:…)` |
| 会话 | `sessionReferenceResolver/candidates` | `@[标题](dsh-session:…)` |
| 本地插件 | 插件自己的 host 方法 `localPlugins()` | `@[名称](dsh-ref:local-plugin:…)`（目录引用） |
| 云盘 / 外部对话 | 插件自建 Remote | 各自的 URI |

**Commands 和 Skills 本质是斜杠命令，不是新的 `MentionKind`。**
快捷词（`@plugin:`、`@commands:`）只是用来缩小搜索范围，不是协议。

## 三、本仓库已有什么（逐项核实，不猜）

| 需求 | 现状 | 位置 |
|---|---|---|
| `@` 工作区文件 / 文件夹 | ✅ 已实现，含模糊搜索、目录钻取、最近记录 | `ui/chat/mention/`、`state/mention_state.dart`、`packages/dsh_client/lib/src/references_api.dart` |
| `@` 历史会话 / 子代理 | ✅ 已实现 | 同上 |
| **Skills / 技能** | ✅ **已经在 `/` 斜杠菜单里**：`SlashCommandKind.skill`，数据来自 `skills/list`，图标 `AppIcons.skill`，注释写明「`/name …` is sent as a normal message and the Host loads the skill」 | `state/commands_state.dart:11-22`、`ui/chat/slash_palette.dart:270` |
| **Commands** | ✅ 同上（`/` 菜单，`SlashCommandKind.host` / `app`） | 同上 |
| **插件** | ❌ `@` 菜单里没有；但客户端有 `listPlugins()`（`pluginManager/listPlugins`） | `packages/dsh_client/lib/src/plugins_api.dart:647` |
| **MCP** | ⚠️ 仓库里只有 `mcp__server__tool` **工具名**的展示处理（`ToolGlyphs`），**没有可列举的 MCP 服务器/工具清单接口** | `ui/common/tool_glyph.dart`、`lib/ui/share/share_content.dart` |

## 四、因此决定怎么做

**不做**：给 `MentionKind` 硬加 `skill` / `plugin` / `mcp`。
理由：`MentionKind` 是**语法层**（`MentionToken.fromRaw` 解析 draft 与已发消息、
`ReferenceText` 渲染 chip）。DSH 的 wire format 只认文件和会话，硬加会让插入的
文本在气泡里解析不出来、引擎也不认。参考仓库同样没这么做。

**要做**：在现有 `@` 菜单里**加一个「插件」分组**，作为唯一真正缺的类别。
- 数据源：`DshClient.listPlugins()` → `PluginEntry`（`moduleName` / `meta` / `enabled`）
- 插入：`@[名称](dsh-ref:local-plugin:<moduleName>)` 形式，或最保守地插
  `@<moduleName> `（纯文本提示，让 Agent 知道去查这个插件）——需按 DSH
  引用协议的 `encodeReferenceUri` 规则定，见 `references_api.dart`
- 通过 `MentionSource` 这个**测试 seam** 加方法，保持 fake 可用

**Skills / Commands**：不重复实现。用户要「@ skill」的意图是「一个输入框里
能快速调出技能」，而 `/` 菜单已承担这个职责且语义正确。若用户坚持要 `@`
也能出技能，再在 `@` 菜单里加一个**只读分组**，选中后插 `/name `（和参考仓库
完全一致），不改 `MentionKind`。

**MCP**：等上游有列举接口再说。当前只做「能从工具名前缀识别 MCP 工具」，
不硬造一个不存在的清单。

## 五、参考仓库里另外值得抄的

- 分组可开关 + 排序（`PickerSourceOptions.order`）；
- 快捷词缩小范围（`scopedQuery`）——例如 `@plugin:` 只搜插件；
- 每组折叠时显示条数上限；
- 类型图标区分来源（文件 / 会话 / 插件 / 技能）。

这些都是 UI 增强，优先级低于「先让插件类别出现」。

## 六、优先级

1. `@` 菜单加「插件」分组（`MentionSource` + `_lookup` + `_assemble`）
2. l10n 分组标题 / 空态
3. 测试（fake `MentionSource` 要跟着加方法）
4. 可选：把 Skills 也作为只读分组加进 `@` 菜单（插 `/name `）
5. 可选：快捷词 / 分组开关（参考仓库的增强项）

## 七、明确不做

- 不改 `MentionKind` 枚举与 `mention_syntax.dart` 的解析规则
- 不改签名（用户要求保持现状）
- 不重拍 golden（工作流会绕过 PR 直接 push main）