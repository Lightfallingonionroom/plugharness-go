# 给执行方（flash）的完整任务提示词

> 生成时间：2026-11-11
> 仓库：`Lightfallingonionroom/plugharness-go`（上游 `ccch1mneyyy/dsh-Go` 的 fork）
> 当前 HEAD：`4574581c`（main，已推送）
> 用法：整段复制给执行方

---

## 你的身份与任务

你是这个仓库的执行工程师。前面一轮"大脑"已经完成了需求分析、架构设计、图标扒取和设计文档，**没有动业务代码**（只加了图标组件和文档）。现在由你负责**全部落地实现 + 跑通所有验证**。

三条铁律，违反任何一条都算失败：

1. **不要为了让 CI 变绿而删测试或改测试期望值。** 测试挂了先查是代码错还是布局变更导致的必然结果。布局变更导致找不到元素的，改测试让它先滚动到目标再断言；**不是**把断言删掉。
2. **不要造第二条数据链路。** 所有 UI 状态必须走已有的 Provider / State 链路。历史上"能选但没用"的 bug 就是这么来的（主题色那次）。
3. **不确定的事实先去代码里核实，不要猜。** 本文档里给了大量文件行号，但代码可能已经变了；行号只作线索，一切以你读到的代码为准。

---

## 零、先读这些（不要跳过）

```
docs/CONTROL_ICONS_AND_THINKING_CONFIG.md      ← 主设计文档，先读完
docs/UI_FEEDBACK_ROUND2_2026-11-10.md          ← 上一轮实机反馈的修复记录与遗留问题
docs/LOCAL_VS_CI.md                            ← 本机与 CI 的分工
docs/PLUGIN_RUNTIME_COMPATIBILITY.md           ← Issue #5 的实现说明
app/lib/ui/chat/control_icons.dart             ← 已备好的图标组件（6 个）
```

---

## 一、UI 改造清单（按顺序做，每步做完先本机快检再继续）

### 1. 设置首页：拆成三个独立框

现在设置首页把主题、字号、宠物等混在一起。改成三个独立卡片：

| 框 | 标题 | 折叠时显示 | 展开后 |
|---|---|---|---|
| A | 强调色 | 一行 + 当前色点 | 框内展开色点（`PalettePicker`，6 预设 + 自定义，单行等距） |
| B | 外观 | 一行 + 当前明暗 | 框内展开 浅色 / 深色 / 跟随系统（`ThemeModePicker`） |
| C | 更多设置 | 一行 | 跳完整外观页（`AppearancePage`：功能图标、桌面图标、启动页、壁纸、字号、收起过程、宠物） |

- 参考现有 `_ThemeRow`（`app/lib/ui/settings/appearance/appearance_page.dart:69`）的就地展开实现
- 官方十色仍然在完整外观页（`OfficialAccentGrid`），**不要**塞回设置首页的单行——11 个色点在 390 宽里每个只剩 21px，会点不中，上一轮已踩过

### 2. 侧边栏改造（这一项上一轮失败过，本次重点）

**目标结构**（对照 ChatGPT 侧边栏）：

```
┌─────────────────────────────┐
│ PlugHarness          (搜索)  │ ← 固定
├─────────────────────────────┤
│ 功能                        │ ┐
│   插件                      │ │
│   自动化任务                 │ │
│   网页版                    │ │ 一整块可滚动
│   更多 ▸（本机引擎/远程主机/ │ │ （和对话同一个滚动体）
│          全部功能）          │ │
│ 对话                        │ │
│   全部对话 ▾  ⋯   [过滤器]   │ │
│   今天 / 会话行…            │ ┘
├─────────────────────────────┤
│ (✎ 新对话)          (⚙)     │ ← 固定
└─────────────────────────────┘
```

**具体要求：**

| 项 | 要求 |
|---|---|
| 左上角 | **纯文字** `PlugHarness`（去掉鲸尾图标和状态行） |
| 右上角 | 搜索圆钮（点开现有会话搜索页） |
| 功能入口 | 只留 **插件 / 自动化任务 / 网页版**，其余收进「更多 ▸」（原地展开，不跳页） |
| 隐藏 | 顶部 `WebModeKey`（⇆ 切换主机） |
| 隐藏 | 底部「本机 · 运行中」整栏（`IdentityBar`） |
| 左下角 | 固定「新对话」胶囊按钮 |
| 右下角 | 齿轮按钮 → 设置（长按 → 设置搜索）。用 `ChatGptGearIcon` |
| 滚动 | 功能行 + 对话标题 + 工作区 + 过滤器 + 会话列表，**全部在同一个滚动体里一起滚** |
| 多选态 | 保持现状：顶行换选择头、底栏换操作条，高度不变 |

**上一轮为什么失败（务必避开）：**

我把功能行当作**一个整体 Column** 塞进 `ListView.builder` 的第 0 项。结果 `drawer_geometry_test` 7 条全红——`DrawerFolderHeader` 和 `SessionTile` 在 600 高的测试屏里被挤出构建窗口，直接找不到。

**这次的做法**（两种都可以，选一种并写注释说明）：

- 方案 A：用 `CustomScrollView`，功能区分成多个小 `SliverToBoxAdapter`，会话仍然是独立 `SliverList`，key 映射原样保留
- 方案 B：把功能行作为 `DrawerConversationList` 的 `leading`（已有参数），扩展它支持多行

**无论哪种，都必须先改测试**：让 `drawer_geometry_test` 在量尺寸前先 `scrollUntilVisible` 滚到目标元素，再断言。这不是"改测试迁就实现"，是布局结构变了，测试的前置条件跟着变。

### 3. 顶栏 / 输入条改动

| 位置 | 改动 |
|---|---|
| 顶栏模型胶囊 | **删掉**（`LongCat 2.5 Preview` 那个） |
| 顶栏右上角 | 新增「查看工作进展」按钮：**点按 → `TerminalPage`，长按 → `WorkspaceFilesPage`**，图标用 `ChatGptTerminalIcon`（显示终端，点按是主操作） |
| 输入条左侧 | 模型名文字改成 `ChatGptStorageBadgeGearIcon` 按钮，点开控制面板 |
| 输入条右侧 | `ReasoningGaugeIcon` 推理强度控制器 |

**输入条左侧控制面板内容**（自上而下）：

```
权限   [仅可查看] [工作区内修改] [完全权限]
模式   [模式选择器]
─────
模型   DeepSeek flash ▾        ← 最下一行，点开现有模型选择弹窗
```

模型选择必须复用现有的 `showModelSheet()`（`app/lib/ui/chat/model_sheet.dart`），不要新写一个。

### 4. 空态精简

`app/lib/ui/chat/empty_state.dart`：**删掉**四张建议卡（`ChatSuggestion`）和底部小技巧。只留：鲸尾 + 时段问候 + 模式/权限两行。

`ChatSuggestion` 这个类如果没别的地方用，一起删掉（先 `grep` 确认）。

---

## 二、推理强度（重点，别做成"能选但没用"）

### 2.1 事实基础（已核实，你可复查）

DSH **原生就有** `reasoningEffort`，而且 dsh-go **已经全链接通**：

| 事实 | 位置 |
|---|---|
| 档位值域 `off / low / high / max` | `dsh-llm-deepseek/lib/index.js:461-464` |
| 引擎写进 profile 配置 | `dsh-agent-default-model/lib/index.js:60-64` |
| `ReasoningEffort(id, name, description)` | `packages/dsh_client/lib/src/models.dart:732` |
| `ModelSelection.reasoningEffort` 全链已通 | `chat_state.dart:1822`、`model_defaults_state.dart`、`scene_accounts_state.dart` |
| 模型弹窗已有档位选择器 | `model_sheet.dart:92-98`（`SegmentedPill`） |
| 中文映射 | `model_sheet.dart:15` `effortLabel` |
| 错误码 | `UNSUPPORTED_REASONING_EFFORT` |
| 默认档推导 | `models_state.dart:143` `startingEffort` |

**所以缺的不是 `reasoningEffort` 本身，是「按模型分别配置」的规则层**（Operit P10–P12 那种）：不同模型命中不同规则、每条规则一套思考配置、可排序启停、首条命中生效。DSH 和 dsh-go 都没有这一层。

### 2.2 要做两件事

**A. 输入条右侧的仪表控制器**

- 图标：`ReasoningGaugeIcon`（已实现，`progress` ∈ [0,1]）
- **档位由 `model.efforts` 决定，不要写死 low/high/max**。DeepSeek 是 4 档，别的模型可能不同
- 档位 i 对应 `progress = i / (n - 1)`；n = 1 时传 0.5
- **没有档位的模型不显示这个按钮**（`model.efforts.isEmpty`）
- 点按 → 弹出档位选择面板（扇形或列表，你按视觉一致性定）
- 长按拖动、抬起按落点定档（第二阶段，先做点按）
- 改档位走现有 `onSelected(ModelSelection(provider, model, reasoningEffort: ...))`，**和模型弹窗同一条链路**

**B. 思考配置页（规则层）**

位置：模型配置页里新增入口，或设置里独立一项。

```
思考配置
├─ 规则列表（可排序、可启停）
│   ├─ 规则：匹配 provider + model（支持通配）
│   │   ├─ 始终开启 / 仅手动
│   │   └─ 档位映射：每档 = { 显示名, 写入值 }  ← 对应 DSH 的 efforts[i].name/.id
│   ├─ …
│   └─ ＋ 添加规则
└─ 未命中时的兜底档位
```

**求值时机：发消息那一刻**，不是打开面板时。规则求值结果**仍然写进 `ModelSelection.reasoningEffort`**，走现有链路进请求。

---

## 三、新增侧边栏入口「自动化任务」

**页面已存在，不要新建**：`SchedulesPage`（`app/lib/ui/features/schedules_page.dart:38`），文案也全在（`l10n.featuresSchedules` = 「自动化任务」）。

要改 4 处（照现有 `DrawerDestination` 的模式）：

| 位置 | 改什么 |
|---|---|
| `ui/shell/drawer/drawer_destination.dart:5` | 枚举加值（如 `schedules`） |
| `ui/shell/quick_panel.dart:11-19` | `icon` switch → `ChatGptScheduledTaskIcon` |
| `ui/shell/quick_panel.dart:21-29` | `label` switch → `l10n.featuresSchedules`（已存在） |
| `ui/shell/home_shell.dart:234-242` | `_openDestination` switch → `const SchedulesPage()` |

**坑**：`DrawerDestination` 按 `Enum.name` 存偏好，**只能新增不能改名**，改名会让用户已存偏好失效。

### 目标页一览（已核实）

| 目标 | 类 | 文件 | 参数 |
|---|---|---|---|
| 终端 | `TerminalPage` | `ui/terminal/terminal_page.dart:35` | `sessionId` |
| 文件 | `WorkspaceFilesPage` | `ui/files/files_page.dart:27` | `sessionId`, `initialPath?` |
| 自动化任务 | `SchedulesPage` | `ui/features/schedules_page.dart:38` | 无 |
| 全部功能 | `AllFeaturesPage` | `ui/features/all_features_page.dart:47` | 无 |

---

## 四、跑验证（这一步是重点，必须做完）

### 4.1 本机快检（每次改完先跑，5 秒）

```bash
tooling/local-fast-check.sh
```

本机是 arm64 Linux，**没有 Flutter SDK**（官方不发 arm64 版），所以 `flutter analyze` / `flutter test` / `flutter build apk` 在本机**做不到**——这是环境事实，不是你偷懒的借口，但也不能假装做了。本机只能跑：Dart 包 analyze + 两个离线 node 套件。

### 4.2 CI 验证（必须等到全绿或确认是既存失败）

推上去后等 CI。当前基线（`df06aadb` / `4574581c`）：

| Job | 状态 |
|---|---|
| `flutter analyze` | ✅ 通过（这个必须保持！） |
| `l10n gen diff` | ✅ 归零（这个也必须保持！） |
| `Android JVM` | ✅ 通过（APK 能构建） |
| `Runtime and bridge` | ✅ 通过 |
| `Dart packages` | ✅ 通过 |
| `Generated files` | ✅ 通过 |
| `Flutter 0/1/2` | ❌ 失败（见下） |

**Flutter 测试失败的构成**（你必须逐项确认属于哪类，不能一句"既有失败"带过）：

1. **golden 失败** —— 按既定方案 C **不重拍**。主题、布局都变了，基准图必然对不上，这是已知的、可接受的。
2. **`palette_contrast_test` 78 条** —— `tertiary`（`#8F8F8F`）对白底实测 3.23，阈值要求 4.5。**这是真实的可访问性缺陷**，`4ed2bebd`「全壳接入官方中性灰阶」那次埋的。它之前没在 CI 出现是因为测试分片按文件排序号取模，新增测试文件把 `NR` 推移后才被分到会执行的片。
3. **其余**（`plugin_controls_parity` 26、`parallel_setup_geometry` 24、`issue52_empty_workspace` 12 等）—— 逐项和 `f6bba727` 的失败数比对过，数量相同，是既存失败。

### 4.3 收尾：清掉能清的红

用户明确说了：**跑完验证后，把之前"没空管"的红色报错也看着改一下**。按这个优先级：

1. **`palette_contrast_test` 的 78 条**：这是真实缺陷，值得修。方向是把 `dusk` 或 `textTertiary` 调到满足 4.5:1，**但这是设计决策**——如果你判断不了，就把它变成一个明确的待决问题写进报告，不要瞎改色值让视觉崩掉。
2. **`flutter analyze` 的任何新告警**：必须清零（当前是 `No issues found!`，不能退步）。
3. **l10n gen diff**：必须保持 0。
4. **其他既存失败**：如果原因是明显的 bug（比如某个断言暴露了真实缺陷），修；如果是 golden 基准图，按方案 C 不碰。

### 4.4 出 APK 并自检

```bash
gh workflow run build-apk.yml --ref main
```
14 分钟。产物约 205 MB。下载后**必须**用 `aapt2` 核对：

```bash
aapt2 dump badging app-arm64-release.apk | grep -E "^package:|application-label:"
```

必须满足（这是红线）：
- `package: name='io.github.lightfallingonionroom.dsh_app'`
- `application-label:'PlugHarness Go'`

---

## 五、确认 5 个 Issue 是否真的实现

5 个 Issue 现在**全是 open 状态**。你要逐个核实代码是否真的落地，并在报告里给结论（实现了 / 部分实现 / 没实现 / 实现但没验证）。

| # | 标题 | 核实线索 |
|---|---|---|
| **#1** | `[Runtime] 校验 Assistant Stream 事件形状，防止插件数据异常击穿宿主` | 找 `assistant-stream-shape.test.mjs`（`runtime/tests/`），确认 patch 存在且哈希钉定 |
| **#2** | `[Runtime] 增强 CrashClassifier 的 Node 插件异常识别与插件版本归因` | 找 `CrashClassifier` 的 Kotlin/Dart 实现与对应测试 |
| **#3** | `[Plugin Manager] 安装前增加 DSH / Node / Cordis 兼容性预检` | `app/lib/state/plugin_compat.dart`，`checkPluginCompatibility()` |
| **#4** | `[CI] 增加通用 Cordis 插件的安装、启用与故障恢复集成测试` | `runtime/tests/cordis-lifecycle.test.mjs`，本地可跑（见 `tooling/local-fast-check.sh`） |
| **#5** | `[Plugin Compatibility] 建立第三方插件运行时兼容性治理与安全迁移机制` | `app/lib/state/plugin_runtime_compat.dart` + `docs/PLUGIN_RUNTIME_COMPATIBILITY.md` |

**核实方法**（不要只看文件在不在，要看行为）：

- 读代码确认逻辑完整
- 读对应测试确认覆盖了 Issue 的验收标准
- 能本地跑的（#4、#5）**真的跑一遍**
- #5 特别说明：**判断层已实现，UI 接线未做**。报告里要如实写这一点，不要写成"已完成"。

报告里对每个 Issue 给出：`实现状态` + `证据（文件/测试名/运行结果）` + `缺口`。

---

## 六、交付报告

写 `docs/FLASH_EXECUTION_REPORT.md`，必须包含：

1. **改动清单**：每个文件改了什么、为什么
2. **验证结果**：本机快检输出、CI 各 job 结论、APK 校验输出
3. **5 个 Issue 的核实结论**（逐条，带证据）
4. **红点处理**：哪些修了、哪些没修、为什么
5. **我踩的坑**：如实写，包括改错的、回退的。上一轮的报告 `docs/UI_FEEDBACK_ROUND2_2026-11-10.md` §七 就是这个格式，照抄风格
6. **待决问题**：需要用户拍板的设计决策

---

## 七、几条经验（省你时间）

1. **`sessions_drawer.dart` 有 1256 行**，改之前先读 §80-330（结构）和 §480-600（`_SessionList`），别通读
2. **l10n 生成文件不能手写**：`app/lib/l10n/gen/*.dart` 是 `flutter gen-l10n` 产出的，手写的格式（换行、引号转义）永远和生成器不一致，CI 的 `git diff --exit-code -- lib/l10n` 会红。改 arb → 本地跑生成器或让 CI 生成后拉取
3. **生成器不按列宽折行**，模板字符串一律单行
4. **`DshSurfaces.card` 是 `GlassStyle`**，写法是 `s.card.fill`，不是 `s.fill`
5. **本机跑 `runtime/build-runtime.sh` 需要先改镜像**：`npmmirror.com` 在这台机器上 `SSL_ERROR_SYSCALL`，改成 `nodejs.org` / GitHub；还需要 `apt-get install -y file` 否则最后一步误报 ABI mismatch。详见 `docs/LOCAL_VS_CI.md`
6. **几何测试挂了先看是不是布局变更的必然结果**，不要第一反应改断言

---

## 八、完成了怎么算成功

- [ ] 设置首页三框可用，点开就地展开
- [ ] 侧边栏：功能行和对话一起滚；插件/自动化任务/网页版三个入口；左下新对话、右下齿轮；⇆ 和底部状态栏已隐藏
- [ ] 顶栏胶囊已删；右上角新按钮点按开终端、长按开文件
- [ ] 空态建议卡已删
- [ ] 输入条左侧控制面板（权限/模式/模型）、右侧推理强度仪表
- [ ] 推理强度真的改了请求参数（不是只有 UI 状态）
- [ ] 思考配置规则页可用
- [ ] `flutter analyze` = No issues found
- [ ] l10n gen diff = 0
- [ ] Android JVM 通过，APK 包名/应用名正确
- [ ] 5 个 Issue 逐个核实并出结论
- [ ] `docs/FLASH_EXECUTION_REPORT.md` 落盘并推送

有任何一项做不到，在报告里写清楚**为什么**，不要假装做到了。

> 夜间补记（2026-11-11）：第一批实现已提交在 `feat/ui-overhaul-flash`
> 分支（`7066fe4e`），**尚未推送**。本机无 Flutter SDK，只做了括号平衡与
> ARB JSON 校验，编译未验证。
