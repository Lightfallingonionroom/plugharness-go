# PlugHarness-Go All-in Flash 实施任务书

> 日期：2026-11-12
> 状态：规划完成，待 Flash 按批次实施
> 产品方向：用户自用产品。All-in 是完整长期路线，不是一次性大提交。
> 当前源码基线：`31c2aabe`，分支 `feat/ui-overhaul-flash`。
> 上游：`ccch1mneyyy/dsh-Go`，AGPL-3.0；本项目不是要求按上游 PR 路线拆分。
> 研究依据：`docs/ALL_IN_RESEARCH_AND_ROADMAP_2026-11-12.md`。
> 遇阻手册：`docs/ALL_IN_FLASH_RESCUE_MANUAL_2026-11-12.md`。
> **实施进度**：`docs/ALL_IN_EXECUTION_REPORT_2026-11-12.md`（Window A、B 已落地；C-F 未开始，含逐轮完工审查与已修问题清单）。后续执行者先读它，不要重做已完成部分。

## 0. 给 Flash 的执行契约

你是实施者，旗舰模型是范围和架构决策者，用户是最终产品决策者。不得扩展范围、推断用户意图或把“规划通过”解释为“允许安装 APK”。

### 0.1 总规则

1. 每次开工先读根目录 `AGENTS.md`、`CONTRIBUTING.md`、`docs/architecture.md` 和本任务书。
2. 开工先记录分支、HEAD、远端、工作树状态。不得清理、暂存、覆盖或格式化无关文件。
3. 本工作区存在 `.backup/chats/` 未跟踪/变化的数据；必须忽略，不得将其加入任何提交、归档或备份任务测试样本。
4. 只暂存明确文件；不使用 `git add .` / `git add -A`。
5. 未经当次明确授权，不 commit、不 push、不创建 PR、不改默认分支、不发布。
6. 本任务书每个批次独立交付。每批写决策记录、改动清单、实际命令和结果、未验证项，再由旗舰模型判定下一批是否开始。**2026-11-12 用户开工令覆盖此条**：授权按窗口顺序连续推进，不因「每窗口停下等检查」而中断；每窗口结束仍必须写报告，遇到 Gate 失败或需产品决策才停。硬停线见 0.3。
7. 任何用户资料、聊天内容、凭据、模型请求正文、截图/OCR 文本都不得写入普通日志、分析遥测或默认备份。
8. UI 字符串改 `app/lib/l10n/parts/` 中英 ARB 输入，再运行生成器；禁止手改生成物。
9. 客户端协议改动必须同步核对 DSH host/bridge/remote 另一端。主机返回才是权限、删除、恢复等动作的事实来源。
10. 本任务不包含安装 APK。除非用户在当次明确说“可以安装”，否则严禁安装或覆盖安装。

### 0.2 不能用来解锁范围的行为

- “源代码看起来支持”不能替代 API/host 真实能力验证。
- “Flutter widget test 通过”不能替代 Android 16 arm64 真机手机操控、PRoot、安装验证。
- “日志里没有错误”不能证明动作成功，必须验证状态回读或真实效果。
- 估算费用不能标成账单；未知 usage 不能改写为 0。
- 取消任务不能声称撤销已经发生的屏幕点击、消息发送、文件写入或付款。
- 标签、模式名、角色名不能代替 permission policy 或 capability enforcement。

### 0.3 本次开工令的边界（2026-11-12）

1. 用户授权「一直干」，即按窗口顺序连续推进，不因每窗口结束自动停手。
2. **硬停线**：APK 实机构建（含 `tooling/build-apk.sh`、触发 Build workflow）与安装/覆盖安装，必须等用户回来后当次明确授权。未获授权一律不执行。
3. 未授权：commit、push、创建 PR、发布、改默认分支、重写共享历史。
4. 不触碰 `.backup/chats/` 中用户运行时数据，也不把它加入任何归档、备份样本或提交。
5. 每个窗口结束仍写报告（目标、改动、命令与结果、未验证项、剩余缺口），然后继续下一窗口；仅在 Gate 失败、需要产品决策、或触及硬停线时停下。
6. 本地无 Flutter SDK 时如实标注「未运行」，不得用桌面/静态检查冒充真机验证。

## 1. 交付结构与任务图

六个工作窗口；按表中任务顺序推进，任务不能跨窗口偷跑。标为 Gate 的任务不通过，不启动依赖它的后续任务。2026-11-12 开工令授权连续推进：每窗口写报告后继续，不在窗口边界停下等待（边界以 §0.3 为准）。

| 窗口 | 主题 | 任务 | 必须先有 | 窗口完成条件 |
|---|---|---|---|---|
| A | UI 入口与颜色纠偏 | AI-A0、AI-00、AI-01、AI-02、AI-02b | 无 | 入口、状态和主题色真机确认，旧入口无重复 |
| B | Provider 与思考配置 | AI-03、AI-04 | AI-00 | 配置不覆盖手工值，规则结果到达真实请求 |
| C | 用量数据与统计 | AI-05、AI-06 | AI-03 的 route identity 决策 | 原始事实、未知值、估算价格诚实呈现 |
| D | 备份与恢复 | AI-07 至 AI-11 | AI-00 的 ownership 确认 | 备份范围明确、校验/预览/恢复可回滚 |
| E | 任务中心、自动化、知识 | AI-12 至 AI-17 | AI-00；手机任务用现有原生 capacity | 统一只读视图，再开放明确支持的操作 |
| F | 电脑入口、扩展中心和高风险研究 | AI-18 至 AI-23 | AI-00、AI-12；各自技术评审 | 按可行性分别交付或维持研究状态 |

A-F 是规划分组，不表示所有窗口一定都能在一个连续工作夜里完成。每个窗口都需要明确通过门槛。

## 2. 统一所有权和状态原则

所有异步工作必须携带不可混淆的归属：

```text
TaskIdentity = { taskId, hostId, sessionId?, workspaceId?, accountId?, kind, generation }
```

- `taskId` 是应用任务身份；不复用 sessionId、terminal tab id 或 schedule id。
- `hostId` 必须区分 local、SSH、DSH Remote 中继、P2P/LAN 等连接来源。
- `sessionId` 可以为空，只允许用于不需要会话资源的任务。需要工作区的终端/文件/团队操作必须明确给 disabled/requires-session，不能偷偷创建会话。
- `accountId` 字段只接入已经批准的账户模型；若当前产品还没有落地场景账户 ID，记录为前置缺口，不制造临时伪身份。
- 回调、流、后台结果、重试都必须核对原始 identity/generation；切换 host/session 不得把迟到结果写给新 owner。
- 通用 Task Center 先聚合已有系统，不另造第二个 Agent loop、job engine、phone task runner 或 schedule engine。

公共状态映射建议：`running / waiting_user / waiting_resource / completed / failed / stopped / cancelled / result_unconfirmed / unavailable`。映射不能抹去源系统的精细错误码和是否已确认事实。

## 3. 分批任务定义

## Window A: 用户确认过的顶部入口和颜色修正

### AI-A0: 本轮只读取证记录（2026-11-12，基线 `31c2aabe`）

旗舰模型已完成以下只读工作，Flash 不必重做，直接采信：

- 分支 `feat/ui-overhaul-flash`，HEAD `31c2aabe`，与 `origin/feat/ui-overhaul-flash` 一致；`app/ packages/ runtime/ docs/` 无已跟踪改动。
- CI：`43045483667`（`31c2aabe`）analyze 全绿；测试 443 条失败，其中 353 条 golden、90 条行为测试。主要行为失败：`onboarding/parallel_setup_geometry_test`(24)、`plugins/plugin_build_consent_owner_test`(8)、`chat/model_sheet_test`(6)、`drawer/drawer_list_lazy_test`(6)。
- 顶部入口现状：终端 `chat_screen.dart:1841`（`WorkProgressKey`）；文件 `chat_header.dart:625`（长按）；团队在 `HeaderTrailingSlot` 内。三点菜单尚未实现。
- 配色现状：默认 `presetId = 'graphite'`（`appearance_state.dart`）；`accentProvider` 未存偏好时回退 `graphite`。
- 截图实测（用户设置页截图）：左侧栏 `#343434`；圆点 紫 `#A89CC0` / 青 `#81AEA7` / 棕 `#B89D7B`。
- 官方设置页实测（ChatGPT App 截图）：页面 `#FBFBFB`、菜单 `#FFFFFF`、外层 `#E6E6E6`。
- 用户已确认：选 **B（全局统一色阶）**，**保留深色/浅色两套**。

### AI-00: 现状、状态流和截图证据冻结（Gate）

**目标**：在实现前确认最新源码、PR #6 目标、用户截图状态和设备体验，避免根据过期截图/构建版本再改错位置或配色。

**输入**：PR #6 评论 `issuecomment-6795097075`；用户 2026-11-11 终端/团队/文件折叠菜单要求；本任务书 §2；当前设备 Android 16 arm64。

**步骤**：
- 只读记录工作树、分支、HEAD、远端和 CI 最近状态。禁止触碰 `.backup/chats/`。
- 从当前代码追出：ChatHeader 行布局、HeaderAgentsKey、WorkProgressKey、ComposerCapsuleBar、TerminalPage、WorkspaceFilesPage、TeamPage。
- 用当前安装 APK/用户截图标注：顶部菜单、标题、终端、团队入口、颜色；记录 APK versionCode 和构建 SHA。如果设备现有安装版本无法确认，不得声称截图与某提交一致。
- 明确 `ChatGptShellColors` 与 `ColorScheme`/`AppAccent` 的运行时优先关系和默认 accent。
- 检查现有 Flutter CI analyzer/tests 最新结果，抽取实际失败名，不修改测试。

**禁止**：先写新 UI 再猜错误来源；以旧报告中“颜色已对齐”当证据；仅根据单张未标明构建版本的截图断言当前代码。

**验收**：证据表包含路径/行号或 commit SHA，能说明顶部三个入口目前在哪；给出 Light/Dark 页面、侧栏、composer、user bubble 的 hex；无工作树变更。

### AI-01: 标题上方三点/三胶囊快捷菜单

**用户契约**：一行放在聊天标题上方并水平居中；关闭是三个横向点；打开是三个横向胶囊：终端、团队、文件；快捷项固定，不加自定义编辑器；取代旧分散的终端/团队入口；新对话页显示但置灰。

**设计先决条件**：
- 不自动创建 DSH session。`sessionId == null` 时保持三个按钮 visible + disabled，含无障碍 disabled 状态和人类可读原因/提示。
- 已有会话点击：终端 → 当前 session TerminalPage；团队 → TeamPage 当前 session；文件 → 当前 session 工作区文件页。
- 替换 `WorkProgressKey` 的独立顶栏入口及 `HeaderAgentsKey` 的重复团队入口，但保留团队页面本身及其他有效的谱系/父级导航；所有引用做调用者盘点。
- 不改终端/文件/团队页面内部行为、会话权限或 DSH 协议。
- 若“屏幕正中上方”与标题/状态/菜单键发生重叠，按用户契约优先，标题可折叠/截断或移到第二视觉层，不得把快捷菜单降到输入框附近。
- 动效只承担展开/收起空间反馈，不添加自动循环装饰；支持 reduce motion。

**实现边界**：建议新组件只负责 expanded 状态、3 个动作和 enabled reasons；路由/权限由 ChatScreen 注入。用稳定组件 Key；进程重建后的默认状态为 collapsed，不持久化用户未要求的展开状态。

**测试**：
- 状态：collapsed 3 dots；展开 3 个标签/胶囊；再点收起；点外部/返回键策略明确。
- 已有会话：三项分别 push 正确 route，sessionId 正确。
- 新对话：三个可见但均 disabled；点按无路由、无 `createSession` RPC、无 pending draft 修改。
- 高字号、360dp、横屏、键盘弹出、中文/英文不溢出；浅/深主题。
- 旧 WorkProgressKey 和 HeaderAgentsKey 不再作为重复入口出现；其他子代理谱系入口仍可达。
- Golden 至少 light/dark，新截图名与旧胶囊 golden 不混淆。

**完成标准**：flutter analyze 零新增问题，相关 widget tests 绿；真机 Android 16 arm64 点击端到端验证；需要用户安装新 APK 才能做的验证等用户授权。

### AI-02: 全局统一 ChatGPT 中性色阶（用户选 B）

**用户契约**：整套 App 统一到 ChatGPT 官方中性色阶；保留深色/浅色两套并跟随系统；强调色十色保持不变。用户明确选 B（全局统一），不是只改设置页。

**已核实的现状**（2026-11-12 只读取证，基线 `31c2aabe`，分支 `feat/ui-overhaul-flash`）：

- `ChatGptShellColors.light/dark` 已改为从 `NeutralTones.forAccent(accent)` 取 `page`/`sidebar`，`graphite` 走 `tintChroma == 0` 短路返回 `defaults` 本体。
- `app_theme.dart` 的 `scaffoldBackgroundColor = scheme.surface`；设置页、引导、弹窗走 `ColorScheme` + `DshSurfaces`，与聊天壳层**不是同一套色**。
- 用户截图实测：设置侧栏 `#343434`（旧深色玻璃），聊天页已是新的白 —— 这就是「颜色根本不一样」的观感来源。
- `docs/ui-refresh-status.md` §21 与 `docs/UI_FEEDBACK_ROUND2_2026-11-10.md` §2.1/§2.2 已记录同一根因，本任务是该结论的执行，不重新论证。

**实测色值对照**（用户截图 + ChatGPT 官方 App 截图交叉验证）：

| 部位 | ChatGPT 实测 | 当前代码 | 常量 |
|---|---|---|---|
| 浅页面 | `#FBFBFB` | `#FFFFFF` | `DshPalette.mistTop` |
| 浅侧栏 | `#F9F9F9` | `#F9F9F9` ✅ | `mistLow` |
| 浅容器 | `#F5F5F5` | `#F3F3F3` | `mistContainer` |
| 浅高亮 | `#ECECEC` | `#ECECEC` ✅ | `mistHigh` |
| 浅分隔线 | `#E5E5E5` | `#E5E5E5` ✅ | `mistHighest` |
| 深页面 | `#1E1E1E` | `#212121` | `nightTop` |
| 深侧栏 | `#171717` | `#171717` ✅ | `nightLowest` |

**实施前必须的证据纠正**（2026-11-12 开工后复核，优先级高于下面的步骤）：

- `app/test/theme/official_palette_test.dart` 已断言 `surfacesDark.backdropTop == shellDark.page`、`dark.colorScheme.surface == shellDark.page`、`light.colorScheme.surface == shellDark.page`。即 **`scaffoldBackgroundColor`（= `scheme.surface`）与聊天壳层 page 已经同源**；旧文档 `ui-refresh-status.md` §21 描述的「两套色板」是**修复前**状态。
- 因此下面步骤 2 不再需要改 `app_theme.dart`；若照抄执行会制造重复改动。
- `official_palette_test.dart` 把 `mist #FFFFFF` / `mistContainer #F3F3F3` / `night #212121` 钉死为 `openai/apps-sdk-ui --gray-*` 源码实测令牌（`docs/openai-sdk-ui-spec.md` §3）。用户截图是 JPEG，实测 `#FBFBFB` / `#F5F5F5` 与官方令牌差 2~4/255，**不能据此把有源码依据的令牌降级为截图近似值**。
- 结论：**不得为对齐截图修改 `DshPalette` 中这三个官方令牌常量**；`official_palette_test` 全绿是硬门槛。
- 用户截图里我们 App 深色侧栏 `#343434`，是 `DshSurfaces.dark.card` 的白色半透明玻璃叠在 `#212121` 页面上算出来的（`33×0.94+255×0.06≈46`），属设计层级，不是残留旧色板。
- 真正剩下的可改项：`ChatGptShellColors.light/dark` 中 `composer` / `composerBorder` / `rowHover` / `rowSelected` / `divider` / `primaryText` 等仍是**硬编码常量**，不随 `NeutralTones.forAccent(accent)` 走；选非 graphite accent 时 page/sidebar 变色而它们不变。把它们改为从 `NeutralTones` 取，才是「全局统一同一套色阶」的准确落地。

**实施步骤（按纠正后的事实执行）**：

1. **不改** `DshPalette` 的 `mistTop` / `mistContainer` / `nightTop`：它们是官方 SDK 源码令牌，被 `official_palette_test` 钉死；截图 JPEG 的 2~4/255 偏差不构成改它们的证据。
2. **不改** `app_theme.dart`：`scheme.surface` 已与 `shell.page` 同源（见上面纠正）。
3. `app/lib/ui/theme/chatgpt_palette.dart`：把 `ChatGptShellColors.light/dark` 中仍硬编码的 `composer` / `composerBorder` / `rowHover` / `rowSelected` / `divider` 改为从 `NeutralTones.forAccent(accent)` 取同明度档，使非 graphite accent 下页面/侧栏/输入条/行态一起变，而不是一部分不动。`primaryText` / `secondaryText` / `tertiaryText` 同样改从 `n.ink` / `n.inkMuted` / `n.inkFaint` 取（深色取 `n.paper` 系列）。
4. 保持 `accent.dart` 官方十色 seed 与 `graphite` 默认 `presetId` 不动；`NeutralTones.of()` 的 `tintChroma == 0` 短路不变。
5. 在 `app/test/theme/` 增加断言：对 `AppAccent.official` 逐个检查 `shell.composer` / `shell.divider` / `shell.primaryText` 与 `NeutralTones.forAccent(accent)` 同源，且 graphite 下 `official_palette_test` 原有 exact-color 断言仍全绿。

**禁止**：

- 不新造第二套色板；不手改生成物；不改官方十色 seed。
- 不把设置页改成纯白而聊天页仍是灰（必须同源）。
- 不删 `palette_contrast_test` / `official_palette_test` / `appearance_page_test` 等既有契约测试。
- 不动 `.backup/chats/`。

**测试**：首次默认 light/dark 的 page/sidebar/composer/action/bubble exact color；`official_palette_test` 中「both halves of the shell agree」已断言 `scheme.surface == shell.page` 与 `DshSurfaces.backdropTop == shell.page`，**无需重复新增**；新增「shell chrome 跟随同一 ramp」遍历 presets + official × 明暗；切换彩色 accent 后壳层仍中性；文字/图标对比度；全部 appearance/contrast tests；light/dark goldens。

**完成标准**：`ChatGptShellColors.light/dark` 的 composer/边框/行态/文字全部与 page/sidebar 同源 `NeutralTones`，选任一彩色 accent 时不再出现「页面变色、控件不动」；graphite 下 `official_palette_test` 原有 exact-color 断言仍全绿；analyze 与相关测试绿；真机 Android 16 arm64 对照截图交回；未获授权不安装 APK；未验证项写明。

### AI-02b: 配色圆点顺序防回归（原「错位 bug」经复核为误报，不修代码）

**证据纠正（2026-11-12 开工后精确重采样）**：之前报的「暮紫显示成棕色」是采样错误。首次脚本只保留高彩度像素，漏采了最上面的「雾蓝」圆点，导致把第 2~4 项错当成第 1~3 项。重新按行扫描（含低彩度）得到四个圆点：

| 截图实测（JPEG） | 对应预设 seedDark | 判定 |
|---|---|---|
| `#7FA8BF` 青蓝 | 黛青 `#8CB9D7` | 色相吻合 |
| `#A89CBF` 紫 | 暮紫 `#B8ABD2` | 色相吻合 |
| `#81ADA7` 青绿 | 松石 `#8DBEB7` | 色相吻合 |
| `#B89D7B` 棕 | 琥珀 `#CCAC87` | 色相吻合 |

顺序与 `AppAccent.presets` 一致，色值偏差来自 JPEG 压缩与截图缩放。**不存在需要修的取色/排序 bug。**

**因此本任务降级为防回归测试**：新增断言，逐个检查 `AppAccent.presets` 与 `AppAccent.official` 的 `seedFor(light)` / `seedFor(dark)` 不为零、不与相邻项同值、且与 `p.label` 的顺序一一对应；不修改任何取色或排序代码。

**禁止**：不得「修」一个不存在的 bug；不得调整 seed 值去贴合 JPEG 实测色。

## Window B: 模型配置与思考行为

### AI-03: Provider preset 与安全自动补全

**目标**：学习 Operit `ApiProviderConfigs` 的数据表原理，不移植 LGPL 代码。每个 provider preset 声明 protocol/default endpoint/endpoint options/default model/credential required/model list behavior。

**已有实现复用**：`providers_state.dart`、`provider_form_page.dart`、`ProviderBackend.discover`、credential reference、read-list epoch/revision。当前已有：按裸域名遇 404 后尝试 `/v1` 的兼容兜底；不要复制成第二套自动修复链。

**冲突规则**：
- preset 选择时只填空字段/明确标记为“由 preset 提供”的字段。
- 用户对 endpoint/model/key 进行编辑后设置 dirty，切换 provider 不覆盖。
- 手工值和系统建议必须视觉区分；“恢复服务商默认值”是单独动作，有当前值预览和撤销提示。
- 不把 API key 保存在普通 provider profile；继续走 credentials/secret store。
- 多 key pool/round-robin 不在这个任务实现，只在数据模型评审中提出选项；API 报错、限流、key 轮换语义要先确认，避免把 401 和 429 都自动切走。

**测试**：每 provider preset 金标准；未知/自定义 provider；字段 dirty；切换 provider 不覆盖；失败/取消发现；空 endpoint；协议不支持；用户清空 endpoint；凭据没有进入日志/导出。

**完成标准**：可重复选择 provider，无未授权覆盖；连接测试和模型目录由主机回执确认；中英文、状态和错误呈现完整。

### AI-04: 思考规则升级

**目标**：逐项对照当前 `ThinkingRulesState` 与 Operit `ThinkingQualityMapping`。扩展前先列当前功能和缺口，不重建规则系统。

**需验证/设计**：provider + model + endpoint 匹配；模型动态 efforts；provider 自定义选项；wire value 类型（string/number/omitted）；JSON request actions；启用/禁用动作；manual/always 与用户手动选择的优先级；规则顺序；规则迁移。

**约束**：
- DSH Host 当前公开接口只接收 `ModelSelection.reasoningEffort` 时，不能假装 App 能注入任意 JSON 请求字段。端点路径动作必须由 Host/bridge 协议支持或被限制在其能力范围内。
- 对主机提供的 model.efforts 做 capability truth；数据缺失显示“未知/未加载”，不写死 low/medium/high/max。
- 用户禁用规则、删除 provider、endpoint 变更、目录失效后不得默默选另一个档位。
- 请求发出前规则结果与实际 Host setModel/提交请求确认关联；手动选择覆盖策略写测试。

**测试**：重叠规则优先级、禁用规则、endpoint 规则、无匹配、未知档、一个档、手动模式、host reject、断线、切换模型迟到结果、设置升级迁移。

**完成标准**：测试证明实际 request path/Host selection 使用目标值；若协议不支持某些 JSON action，只交付 UI/模型能力检测与“不可用”状态，不造本地假设置。

### Window B 实施结论（2026-11-12，写在实际落地后）

供后续窗口避免重复劳动或误判「还有一半没做」：

- **AI-03 已交付**：`app/lib/state/provider_presets.dart`（12 行 preset 表）、`provider_form_page.dart` 的服务商下拉与「只填空字段」填充、`app/test/providers/provider_presets_test.dart`。第二轮审查补齐了 `requiresKey`（本地 preset 免密，否则 `_discover`/`_save` 会挡住保存）、`defaultModel`（自动补建议模型，`_presetModelId` 保证不覆盖用户手建列表）、切换 preset 时协议跟随。
- **AI-03 未接线**：`endpointOptions`（国内/国际备选地址）只在数据表声明，表单无切换 UI。这是刻意留下的小缺口，不是遗漏的实现；需要 widget 测试环境才能安全补。
- **AI-04 已交付**：`_matches` 补上头部/两侧/中间 glob 且大小写不敏感（历史 `*`/`deepseek-*` 语义不变）；`chat_screen.dart` 修了 `setModel` 返回值被丢弃的真 bug（Host 拒绝时 `_giveBack` 并中止发送）；`app/test/providers/thinking_rules_test.dart` 8 条纯函数测试。此前该模块零测试。
- **AI-04 明确不做**（协议事实，见执行报告）：`ModelSelection` 只有 `provider`/`model`/`reasoningEffort`，**无 endpoint 字段**，故 endpoint 匹配、endpointSuffix 规则、JSON request actions、wire value 三种类型、enable/disable 动作在本项目没有数据落点；DSH 只暴露 `setModel(reasoningEffort)`，不注入任意 JSON 请求字段。这些不是待办，是经核实后的「不可用」。
- 上面 AI-04「需验证/设计」「测试」两段的清单是调研期的候选面，实际交付以上述结论为准；其中「规则顺序 / 禁用规则 / 无匹配 / 手动模式 / unknown 档 / host reject」已由新增测试覆盖，「切换模型迟到结果 / 设置升级迁移 / 断线」仍未覆盖，留待有 Flutter 测试环境后补。

## Window C: 用量统计

### AI-05: Usage 事实源和事件契约

**来源**：当前 `SessionUsage` 是实时投影，不是可直接分页的跨会话账本；逐步检查 DSH session logs/event fields、TurnTrace 和 provider response usage。每个来源记录可靠性与可访问范围。

**数据模型**至少包含：event ID/idempotency key、host/session/account?、provider/model/route、timestamp + timezone source、input/cache read/cache write/output/reasoning 各自 nullable、currency/price source/price timestamp、source type (host projection/provider billing/imported)。不得把 nullable unknown 变 0。

**约束**：
- 不得记录 prompt、completion 正文、API key、cookie、用户文件名或完整主机 URL。
- 没有 host acknowledgement / stable event id 时不对同一轮重复导入；按 source identity 去重。
- provider 返回的 billing amount 与按本地公开价表估算必须区分。
- 远程主机历史不可取时明确说明，只显示当前可见会话用量。

**完成标准**：数据契约文档、测试夹具和来源能力表通过评审后，才能进存储 UI。

### AI-06: Token 统计存储、汇总和页面

**范围**：本地数据库迁移（如确有必要）或主机历史查询（若协议支持）；日/7日/30日/自定义、按 provider/model、缓存比例、cost known/unknown、CSV/JSON 导出。

**验收**：迁移从旧 schema 可回滚；重试不重复计数；跨时区和夏令时边界；无 usage、未知 usage、负/超大异常值；页面 loading/empty/error/offline；导出 redaction；提供一份可复现聚合 fixture。

## Window D: 备份与恢复

### AI-07: 备份范围、数据所有权与风险清单（Gate）

逐类列出 App settings、credentials、local rootfs/`/root`、host plugins/profile、sessions、attachments、workspace files、memory/skills、remote hosts、phone task state。为每项列数据 owner、API/文件路径、能否读、能否恢复、是否含 secret、上限、跨版本行为。

**首版不默认备份**：完整 API keys/tokens/cookies/login sessions、手机截图/识别文本缓存、rootfs/二进制运行环境、远程主机数据库直接拷贝。

Gate 结论必须由实际接口/文件/host response 支持；不支持的类别标 unsupported，不用“导出聊天日志”冒充完整备份。

### AI-08: 本地可恢复备份格式与创建

- 版本化 manifest、SHA-256、分块/总尺寸上限、路径规范化、zip-slip 防护、压缩炸弹限制。
- 临时目录写入、flush、校验、原子 rename；崩溃前后都可判定旧备份/新备份哪个可信。
- retention policy 明确，用户可见空间和删除行为。
- 手动备份第一，自动周期备份需用户 opt-in，并在后台限制电量/网络。
- 不备份用户从没选择的 host data；任何敏感配置默认排除。

### AI-09: 备份检查、预览与差异

只读验证包版本、来源、内容数量、是否含敏感或不支持项；显示“可恢复/只能导入部分/此版本不可恢复”。恢复前 preview diff，允许逐类选择，不能默认全覆盖。

### AI-10: 本地恢复、还原点和回滚

恢复时先写可验证 restore point；按 dependency order 应用；每步骤结果 journal；断电/进程被杀后能恢复原状或安全继续；失败不得显示完整成功；运行中的 DSH 必须按契约停止/重启，错误期间保留原备份。

### AI-11: 主机/远程备份适配（Gate）

只有当 dsh_client/bridge/host 提供明确 export/import API 时才启用。SSH/Relay/P2P 各自单独验证。远程主机无接口时给出受限提示，不试图读远程 SQLite、不使用宽权限文件读取绕过。

## Window E: 统一任务中心和手机 Agent

### AI-12: Task Center 只读聚合

聚合 `chat run / job / phone task / schedule / team` 的现存状态；先只读，不添加控制动作。每项显示 owner、host/session、状态、progress、last updated 和 source feature。

测试 stale data、source unavailable、旧协议、多个 host 同 session id、disposed provider、状态未知。

### AI-13: 任务停止/恢复/排队操作

逐个连接源系统现有 RPC，使用真实 ack；暂停只有后端明确支持才画；取消与已经发生的动作边界说明清楚。每个动作执行后状态回读。不可确认显示 `result_unconfirmed`，不得自动重试可能重复产生副作用的动作。

### AI-14: 手机后台资源互斥与队列 UX

复用原生 `PhoneTaskSessions` admission/capacity/backgroundSlot。做 UI 的排队状态、已占槽任务、App/package conflict、超时、死锁提示、资源清理 pending、重试 cleanup。新 UI 不可放宽原生互斥或 bypass capability gate。

### AI-15: App/网站知识包原型

只读 signed/verified 或用户本地知识文档；manifest 有 package/domain/version/source/hash；启动加载白名单；检索结果标来源/版本；知识内容不带权限、不能指示绕过用户确认。原型限定一个明确场景，做对照任务成功率/步骤数评估，不直接导入 Mika 数据。

### AI-16: 条件 schedule

扩展现有 schedules 协议。条件类型先由主机能力决定，不支持的服务端能力不在 UI 伪造。定义 baseline、comparison source、dedupe key、quiet hours、maximum alerts、zone、failure policy。

### AI-17: 统一 trace 与任务结果

复用 TurnTrace/phone action log/job output/schedule history，聚合时间轴但保留原事件引用。来源链接回原 session/任务；敏感参数脱敏；未知因果关系标“来源未确认”。

## Window F: 外部入口、扩展和高风险能力

### AI-18: 风险模式策略评估

对照现有 `policy/permission/capability`，形成 capability matrix，而非新增“自主”全局绕过开关。分别列 low-risk/read、write、external side effect、money/auth/sensitive apps；任何付款/凭据/用户明确禁止仍由安全硬约束决定。先产品评审和状态矩阵测试，后实现。

### AI-19: 电脑 CLI/Skill 派任务原型

只做本地 USB/ADB 原型，复用 TaskIdentity、outbox、existing phone task service。MCP 与 CLI 不能双建队列。扫码/令牌只按用户显式开启，默认关闭；先 threat model 和设备对验证。

### AI-20: 统一扩展中心评估

现有插件、MCP、Skills 各有不同 owner/installer/secret storage。先建 capability catalog + lifecycle status adapter；首版可做只读统一视图，不立刻重写安装系统。凭据引用按 extension id scope，禁止将共享 key 当默认。

### AI-21: 本地模型技术探测（不等于实施）

限于技术 spike：APK/磁盘预算、ARM ABI、16K page alignment、下载完整性、RAM 峰值、LLM tool calling、生命周期/停止释放。达到测量门槛再独立产品决策；不能把 APK 体积或设备内存风险隐藏。

### AI-22: 浏览器 Agent / 用户脚本可行性评估

现有 browser probe 边界已知：能渲染/读结构/交互但不能截图，严格 CSP 下 snapshot/evaluate 被拒。不得因为 Operit 有浏览器 Agent 就承诺所有网站支持。只列浏览器插件、系统浏览器、Accessibility/截图各路径的能力矩阵和隐私边界。

### AI-23: 可视化工作流 / 角色卡 / 记忆图谱规划

先复用 DSH schedules/jobs/subagents 与已确认账户隔离原则。统一按高风险单独评审，不做第二套 Agent loop；跨 account 检索先授权/隔离，再排序和 TopK。

## 4. 每批统一验收门槛

1. **代码质量**：Flutter analyze 零新增 issue；目标 tests 全绿；修测试不可删除有效断言或降低期望值。
2. **本地可跑项**：执行 `tooling/local-fast-check.sh`（若存在且适用）、相关 Dart/Node suites、`python3 app/tool/l10n_merge.py --check`、`python3 app/tool/guide_sync.py --check`。
3. **CI**：等待包含当前 SHA 的 CI 完成；记录各 job 与失败测试名称；不在 CI 运行中反复 push 取消它。
4. **真机**：所有 Android/PRoot/Accessibility/Shizuku/后台屏/通知/安装行为在用户指定设备 Android 16 arm64 验证；未授权安装时不安装。
5. **隐私**：变更日志/诊断/备份/导出人工检查，不带密钥、token、聊天正文、截图或个人路径。
6. **产品验收**：每个 UI 操作逐项记录 click-through；空/加载/错误/离线/权限拒绝状态齐全；中英、浅深色、大字号。
7. **完成报告**：目标、实际改动、测试命令输出摘要、CI URL/SHA、真机证据、剩余缺口、未验证项、后续 task IDs。

窗口门槛：

- A 必须真机观察顶栏、不创建会话、不重复入口；颜色提交截图和 hex 对照。
- B 必须证明保存的 preset/rule 到达真实 Host/model request path。
- C 必须证明数据来源、去重、unknown 语义和价格来源，不能只验证 UI 汇总。
- D 必须完成至少一次损坏包拒绝、恢复中断恢复、恢复失败回滚、密钥排除。
- E 必须证明任务归属、槽位等待、清理失败保护和旧 host 降级。
- F 的原型/研究任务若没有可用主机或用户设备，必须明确标“未完成验证”，不得交付为已支持功能。

## 5. Flash 总任务启动说明

Flash 启动时只读本文件和对应窗口 task，不允许自行选择多个窗口。每一窗口一次独立范围。用户明确要求“别写任务书”在本轮已被后续明确指示覆盖；但用户没有授权构建/安装/发布。

开始 AI-00 前不得改源码。AI-00 产出只读证据报告，由旗舰模型检查再开始 AI-01。

一个窗口完成后停止，等旗舰模型检查：

- 若代码/测试/真机证据满足窗口门槛，旗舰发下一窗口任务。
- 若有决定性假设失败，先修架构/实验，不继续堆叠 UI。
- 若只是本机无 Flutter，转 CI；若 CI failed 必须取失败名和最小日志，不臆测，不反复 push。
- 不允许最终 APK 自动安装。等待用户明确“可以安装”。