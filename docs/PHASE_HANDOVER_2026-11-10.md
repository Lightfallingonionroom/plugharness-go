# 阶段交接报告（2026-11-10）

> 交接点：Run #162 完成，Runtime 阶段结束，进入 ChatGPT UI 阶段。

---

## 一、CI 验收（Run #162 / `a1e796b5`）

**结论：三项关键 Job 通过，Flutter 仍有既有失败，未新增。**

| # | 检查项 | 结果 |
|---|---|---|
| 1 | Runtime and bridge | ✅ **success** |
| 2 | Android JVM | ✅ **success** |
| 3 | Flutter Analyze | ✅ **success**（`No issues found!`） |
| 4 | Flutter 0/1/2 剩余失败 | ❌ 147 / 95 / 70 |
| 5 | 是否有新增失败 | **无**（与 Run #161 逐项一致，通过数也相同） |

补充通过的 Job：`changes`、`Dart packages`、`Generated files, tooling, SDK, web` 均 success。

> ⚠️ 未宣布整个 CI 通过。`CI OK` 汇总门禁仍为 failure，因为 Flutter 三个 job 未绿。

### Flutter 失败分类（Flutter 0，147 个）

| 数量 | 文件 | 性质 |
|---|---|---|
| 79 | `theme/palette_contrast_test.dart` | 既有对比度断言（`#8F8F8F` 低于 4.5） |
| 26 | `plugins/view/plugin_controls_parity_test.dart` | 既有布局断言 |
| 6 | `chat/empty_actions_test.dart` | golden 基准图 |
| 4 | `session/conversation_panel_test.dart` | 既有 |
| 4 | `phone/phone_floating_bar_test.dart` | 既有 |
| 4 | `onboarding/local_chat_golden_test.dart` | golden |
| 28 | 其余（golden / widget） | golden 或既有 |

Flutter 1 / 2 同理，构成相同量级。

---

## 二、Runtime 阶段收尾（Issue #1–#4）

### 最终测试证据

| Issue | 验收标准 | 证据 | 状态 |
|---|---|---|---|
| **#1** | Assistant Stream 事件形状异常不得击穿宿主 | `runtime/patches/...assistant-stream-shape.diff`<br>`runtime/tests/assistant-stream-shape.test.mjs`（6 条）<br>哈希链 `8e541fc9→2f3e4c54→57b013af→143b2c18` | ✅ CI Runtime 通过 |
| **#2** | 识别 Node 未捕获异常并归因版本 | `CrashClassifierTest.kt` **15 个 @Test**<br>覆盖 `nodeUncaught` / `isRequireFailure` / `SuspectSource` | ✅ Android JVM 通过（2054 测试） |
| **#3** | 安装/更新前做兼容性预检并拦截 | `packages/dsh_client/lib/src/version_range.dart`<br>`packages/dsh_client/test/version_range_test.dart`<br>`app/lib/state/plugin_compat.dart` 接入 `plugin_actions.dart`（3 处） | ✅ analyze 零问题 |
| **#4** | 通用 Cordis 插件生命周期测试 | 3 fixture（`cordis-basic`/`cordis-throws`/`cordis-badmain`）<br>`runtime/tests/cordis-lifecycle.test.mjs`（3 场景） | ✅ CI Runtime 通过<br>✅ 本地 3/3 通过 |

### 证据可信度说明（重要）

- **#4**：本地用真实 DSH 跑 `node --test` → **3/3 pass**，CI 同样通过。双端一致，证据最硬。
- **#1**：本地副本 `/root/t29probe` 是**未打 patch** 的 0.2.1-rc.2，`reportMalformedAssistantChunk` 计数为 0，故本地 6 条测试有 4 条预期失败。**验证以 CI 为准**（CI 环境中 patch 已应用，Runtime job 通过）。
- **#2**：Kotlin 单测跑在 CI 的 `Android JVM`，本地无 Gradle/Android SDK。
- **#3**：靠 CI `flutter analyze`；本地无 Flutter SDK。

### 已知遗留（明确不在本阶段处理）

- 79 个 `palette_contrast` 与 `official_palette_test` 的**断言互相矛盾**：前者要求 `#8F8F8F` 达标 4.5，后者硬钉死 `inkFaint == 0xFF8F8F8F`。需产品决策，不是代码 bug。
- 其余 Flutter 失败为 golden 基准图差异。

**Runtime 功能暂停扩展。** 后续除阻塞性缺陷外，不再新增 Runtime 治理。

---

## 三、Flutter UI 架构审计

### 3.1 聊天主页及组件树

```
HomeShell (607 行)                          ← 单一 AnimationController 驱动抽屉
├─ ChatScreen (2475 行)                     ← ⚠️ God Object
│  ├─ ChatHeader (928)
│  ├─ ChatEmptyState (342) ─── 纯展示，0 处 Riverpod ✅
│  │  ├─ SuggestionCards (empty_actions 688)
│  │  │  └─ SuggestionCard → 自适应 2 列 / 1 列
│  │  ├─ TipLine（7 秒轮换）
│  │  └─ QuietChip / EmptyPrimaryPill
│  ├─ ChatList (1421)
│  ├─ Composer (911)
│  └─ ChatDock / 媒体 / dsh_ui 渲染层（约 4 万行）
└─ SessionsDrawer (1165)
   ├─ IdentityBar
   ├─ NewChatButton
   ├─ _SessionList → SessionTile (247)
   └─ 空态 / 骨架屏
```

**规模**：`ui/chat` 共 **52,347 行**；`chat_screen.dart` 单文件 2,475 行。

### 3.2 导航与页面层级

- **命令式导航**，无 `GoRouter` / 命名路由。`app.dart:204` → `RootGate` → `ModeHome` → `HomeShell`。
- 二级页统一 `Navigator.push`，符合设计规范 §5「iOS 式水平推入」。
- **风险**：无集中路由表，深链/返回栈行为分散在各页面。

### 3.3 Drawer 组件与状态管理

- 状态：Riverpod `NotifierProvider`
  - `drawerViewProvider`（视图/文件夹）
  - `drawerFilterProvider`（过滤）
  - `drawerSelectionProvider`（多选）
  - `drawerScopeProvider`（聚合作用域）
- **按 host 隔离**：所有 controller 都 `ref.watch(activeHostProvider)`，多主机切换不串数据 ✅
- 手势：`AnimationController` 跟手，右滑开、左滑推回，不与 QuickPanel 抢手势 ✅

### 3.4 模型选择与工作区

- 模型：`models_state.dart` + `model_defaults_state.dart`；入口 `ChatScreen._showModelSheet()` → `model_sheet.dart`（1030 行）；`ComposerModelPill` 常驻输入条。
- 工作区：`workspace_state.dart` + `workspaces_state.dart`；空态 `QuietChip` 展示当前工作区并可切换。
- 新对话选项：`new_chat_options.dart`（308 行）——文件夹 / 预设 / 权限三项。

### 3.5 Design Token、主题与组件复用

| 指标 | 数值 | 评价 |
|---|---|---|
| `ui/chat/*.dart` 硬编码颜色 | **1** 处 | ✅ 优秀 |
| 硬编码 `fontSize` | 16 处 | ⚠️ 少量 |
| `DshColors.of` / `ChatGptShellColors.of` | 59 处 | ✅ |
| `AppSpace.*` / `AppShape.*` | 38 处 | ✅ |

**两套并行配色仍存在**：`ChatGptShellColors`（聊天壳）+ `DshColors`（233 个文件）。`4ed2bebd` 已统一中性色阶，但仍是两套 API。

### 3.6 UI 对上游业务逻辑的耦合度

| 文件 | `ref.read`/`ref.watch` 次数 |
|---|---|
| `chat_screen.dart` | **194** ← 严重耦合 |
| `chat_list.dart` | 30 |
| `empty_state.dart` | **0** ← 纯展示，可直接复用/改版 |

**结论**：展示层与业务层分离得不彻底。`ChatScreen` 同时承担：会话生命周期、草稿持久化、语音输入、@ 提及、插件宿主、布局测量、导航。**任何改版都必须绕开它，从纯组件入手。**

### 3.7 目标手机尺寸下的布局

- 断点：`compact < 600`、`medium 600–840`、`expanded ≥ 840`；**高 < 480 一律 compact**（横屏手机）。
- 记录在案的目标尺寸：**320 / 390 / 915×412（横屏）**。
- 字体缩放：`TextPainter` + `MediaQuery.textScalerOf` 精确测量（`chat_header.dart:533`、`composer.dart:143`），`SuggestionCards` 在字号变大时自动降为单列 ✅
- 已存在的横屏 golden 测试目录：`app/test/landscape/`。

---

## 四、关键审计发现（决定设计方向）

### 发现 1：设计规范与实现已经分叉 ⚠️

`docs/design/page-design.md §3` 明确要求聊天空状态包含：

> 「居中偏上，**鲸尾品牌形**（静态、很淡的蓝）+ **按时段的问候**（「下午好」）+ 一句很短的副标题」

**但代码里没有**。`empty_state.dart:283` 的注释写着：

> "ChatGPT's new-chat screen is a single question. **No mascot, no greeting by the hour**"

这是上一轮「照抄 ChatGPT」时把产品身份抹掉了。

### 发现 2：品牌能力是死代码

`greetingFor(DateTime now)`（`empty_state.dart:103-109`）函数完整保留，五种中文问候文案（早上好/中午好/下午好/晚上好/夜深了）**全部在 l10n 里**，但 **零调用**。

> 改造成本极低，收益极高——恢复即可。

### 发现 3：建议内容与产品无关

`defaultSuggestions` 是 4 个硬编码项：看看工作区 / 词频统计脚本 / 新建 Node 项目 / rebase 或 merge。这是**通用开发工具**的默认值，与 PlugHarness「插件宿主 / 手机操控」的产品定位无关。

### 发现 4：`ChatScreen` 是改版的最大障碍

2,475 行 + 194 处 Riverpod 访问。**改版必须从 `empty_state.dart`（0 处依赖）切入**，不能动 `chat_screen`。

---

## 五、下一阶段设计目标

### 产品定位

PlugHarness Go 不是「ChatGPT 的复刻」，而是 **把 Agent 装进口袋、能操作手机、能装插件的宿主**。UI 应体现：**能力可见、状态可信、控制可得**。

### 设计目标（拟）

| 目标 | 说明 |
|---|---|
| **恢复品牌身份** | 空态恢复鲸尾品牌形 + 时段问候，但用 ChatGPT 的克制排版（不堆装饰） |
| **让能力可见** | 建议卡从「通用开发任务」改为 PlugHarness 独有能力：手机操控、插件、工作区、日程 |
| **单一信息焦点** | 保持输入框为唯一主角（设计规范 §3 原话） |
| **不破坏既有能力** | 零改动 `ChatScreen`；只替换 `empty_state` 的内容层 |

### 组件边界（不改动区）

```
✅ 允许改动：empty_state.dart（内容层）、empty_actions.dart（卡片）
❌ 禁止改动：chat_screen.dart、chat_list.dart、composer.dart、所有 state/*
```

---

## 六、下一步（待确认后执行）

1. **出设计稿**：空态新布局（鲸尾 + 问候 + 4 张能力卡），先文本化说明尺寸/间距/字号。
2. **截图对比**：改前 / 改后（390 竖屏 + 915×412 横屏 + 320 窄屏 + 1.3× 字号）。
3. **建 Golden 基准**：新建 `test/chat/empty_state_brand_test.dart`，**不复用旧 golden**。
4. **交互验证**：点击建议 → 填充输入框；问候随时段变化；字体缩放不溢出。

> 阶段禁止事项已确认：不扩大 Runtime、不做上游合并、不批量更新 golden、不删测试、不做无目标全局重构。
