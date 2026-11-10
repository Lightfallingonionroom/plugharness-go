# 输入条双控制器 + 思考配置 · 设计文档

> 图标矢量来源：ChatGPT 官方 Android 包 `com.openai.chatgpt` 1.2026.300
> 代码：`app/lib/ui/chat/control_icons.dart`
> 日期：2026-11-11

## 一、图标：从哪来，为什么是矢量

你给的参考图里，「历史记录与资料」那一项的图标是**两半圆柱 + 右下角齿轮**。
它在 ChatGPT 官方包里确实存在，名字就叫这个：

```
assets/composeResources/com.openai.kmp.platform.design.resources/drawable/
  ds_storage_badge_gear_regular_24.xml
```

同目录下还有一整套 `ds_*_regular_24.xml`（`ds_gear_regular_24`、
`ds_gauge_regular_24`、`ds_sliders_regular_24`、`ds_deep_research_regular_24`…），
都是 24×24 视口的 Android vector。

**为什么用矢量而不是截屏**：这两个按钮要随主题变色、推理强度那个还要随档位
旋转，位图做不到。矢量数据是官方原值，不是我近似重画——所以画出来一定和
ChatGPT 里的一样。

| 用途 | 组件 | 来源 |
|---|---|---|
| 输入条左侧「控制面板」按钮 | `ChatGptStorageBadgeGearIcon` | `ds_storage_badge_gear_regular_24.xml` |
| 底栏右下角设置入口 | `ChatGptGearIcon` | `ds_gear_regular_24.xml` |
| 输入条右侧推理强度 | `ReasoningGaugeIcon` | 用户提供的 SVG（270° 弧 + 指针） |

### 关于推理强度图标为什么不用官方的 `ds_gauge`

`ds_gauge_regular_24.xml` 是**静态仪表**：弧 + 指针 + 中心点都固定在图上，
指针不随档位动。而你要的是「随着强度选择改变」。所以强度图标按你给的
HTML/SVG 复刻，官方那个留作备选（如果将来想做静态版可以换）。

## 二、`control_icons.dart` 里有什么

### 2.1 两个官方图标

```dart
ChatGptStorageBadgeGearIcon(size: 20)   // 两段 path：gear + cylinder
ChatGptGearIcon(size: 22)               // 两段 path：ring + body
```

内部走 `parseVectorPath()` 把 Android 的 `pathData` 解析成 Flutter `Path`，
再用 `PathFillType.evenOdd` 填充。

**解析器刻意只支持 `M/L/C/H/V/Z` 与小写相对形式**，遇到别的指令**抛异常**。
理由：官方这两个图标只用了这些指令；真出现别的，静默画错比报错更难查。

**`evenOdd` 不能省**：齿轮的中心孔、圆柱的分层是靠填充规则挖出来的洞，
不是叠色遮出来的。用默认的 `nonZero` 会画成实心。

### 2.2 推理强度仪表（按你的 SVG 复刻）

```dart
ReasoningGaugeIcon(size: 24, progress: 0.5)
```

复刻要点（与 SVG 原文逐项对应）：

| SVG 参数 | 值 | 代码里 |
|---|---|---|
| 视口 | 100×100 | `scale = size.shortestSide / 100` |
| 半径 | 38 | `_radius = 38.0` |
| 线宽 | 8 | `_stroke = 8.0` |
| 弧占比 | 0.75（270°） | `_arc = 0.75` |
| 圆环旋转 | `rotate(135 50 50)` | `canvas.rotate(135°)` |
| 指针角度 | `225 + 270 × progress` | `angle = (225 + 270 * p)` |
| 指针长度 | 指向 (50,22) → 半径 28 | `length = _radius - 8` |
| 中心圆点 | r = 5.5 | `drawCircle(…, 4.5)`（略收，视觉更稳） |

`progress` ∈ [0, 1]；档位 i 对应 `i / (n - 1)`。n=1 时传 0.5（居中）。

### 2.3 已验证

```
$ python3 /tmp/check_icons.py
ok  : imports all at the top
ok  : paren balanced
ok  : brace balanced
ok  : bracket balanced
ok  : 7 declarations, no duplicates

$ python3 /tmp/render_icons.py
wrote /tmp/icon_preview.png (288x288)
wrote /tmp/icon_gear_only.png (288x288)
wrote /tmp/icon_plain_gear.png (288x288)
```

渲染结果在 `/sdcard/Download/icon_check.png`（左：存储+齿轮，中：齿轮单独，
右：普通齿轮）。**这张图是我用 Python 按同一份 pathData 画的**，用来在
没有 Flutter 的机器上确认形状；真正上屏效果以 APK 为准。

## 三、思考配置：DSH 有什么，我们缺什么

### 3.1 DSH 原生已有的（已核实）

| 事实 | 位置 |
|---|---|
| 档位值域 `off / low / high / max` | `dsh-llm-deepseek/lib/index.js:461-464` |
| 引擎把 `reasoningEffort` 写进 profile 配置 | `dsh-agent-default-model/lib/index.js:60-64` |
| `ReasoningEffort(id, name, description)` 数据结构 | `packages/dsh_client/lib/src/models.dart:732` |
| `ModelSelection.reasoningEffort` 全链已通 | `chat_state.dart:1822`、`model_defaults_state.dart`、`scene_accounts_state.dart` |
| 引擎设置页已有「思考深度」 | l10n `engineFieldReasoningEffort` |
| 模型选择弹窗已有档位选择器 | `model_sheet.dart:92-98`（`SegmentedPill`） |
| 中文映射 | `model_sheet.dart:15` `effortLabel` |
| 错误码 | `UNSUPPORTED_REASONING_EFFORT` → `turn_failure_text.dart:25` |
| 默认档推导 | `models_state.dart:143` `startingEffort` |

### 3.2 缺的是「按模型分别配置」的规则层

DSH 的 `reasoningEffort` 是**一个全局字段**：换模型时它不跟着变，
每个模型支持哪些档位也不同（`model.efforts` 是逐模型的）。

Operit P10–P12 那套是**规则列表**：
- 不同模型命中不同规则
- 每条规则一套思考配置
- 可上下排序、可启停
- 首条命中生效

**DSH 和 dsh-go 都没有这一层。** 所以要做的是：

```
前端控制器（扇形）
   ↓ 读
思考配置（规则列表，App 侧存储）
   ↓ 发消息那一刻，按「当前模型 + 请求路径」求值
第一条 enabled 且命中的规则
   ↓ 取它的 level
ModelSelection.reasoningEffort  →  走现有链路进请求
```

**关键：不能另造一条链路。** 规则求值的结果仍然写进
`ModelSelection.reasoningEffort`，和模型弹窗、引擎设置页完全同一条路。
否则会变成「能选但没用」——主题色那次就是这么踩的。

### 3.3 配置页面结构

```
思考配置
├─ 规则列表（可排序、可启停）
│   ├─ 规则 1：DeepSeek 全系 → 始终 low
│   │   ├─ 匹配：provider = deepseek，model = *
│   │   ├─ 始终开启 / 仅手动触发
│   │   └─ 档位滑块：每档 = { 显示名, 写入值 }
│   ├─ 规则 2：…
│   └─ ＋ 添加规则
└─ 未命中时的兜底档位
```

每档的 `{显示名, 写入值}` 对应 DSH 的 `efforts[i].name / efforts[i].id`，
**不写死**。

## 四、执行顺序（给执行方）

1. **设置三框**（强调色 / 外观 / 更多设置）—— 最独立
2. **侧边栏整列滚 + 功能折叠 + 新底栏** —— 带 `drawer_geometry_test` 修改
3. **删顶栏胶囊 / 删空态建议卡 / 输入条双控制器**
   - 左：`ChatGptStorageBadgeGearIcon`
   - 右：`ReasoningGaugeIcon`（档位由 `model.efforts` 决定，无档位不显示）
4. **思考配置页面** + 扇形接进输入条（复用 `ModelSelection.reasoningEffort`）

## 四点五、右上角「查看工作进展」+ 侧边栏「自动化任务」（追加需求）

用户看过 P1（终端）、P2（文件）、P3（自动化任务）三个页面后追加：

### 右上角按钮：一个图标，两种动作

顶栏右上角**保留一个图标按钮**（不再是模型选择）：

| 动作 | 打开 | 组件 | 官方来源 |
|---|---|---|---|
| **点按** | 终端页 | `ChatGptTerminalIcon` | `ds_terminal_regular_24.xml` |
| **长按** | 文件页 | `ChatGptFolderIcon` | `ds_folder_regular_24.xml` |

图标本身显示成终端（因为点按是主操作），长按进文件。

对接的页面类（已核实存在）：

| 目标 | 类 | 文件 |
|---|---|---|
| 终端 | `TerminalPage`（需 `sessionId`） | `app/lib/ui/terminal/terminal_page.dart:35` |
| 文件 | `WorkspaceFilesPage`（需 `sessionId`） | `app/lib/ui/files/files_page.dart:27` |

### 侧边栏功能入口：三行

```
功能
  插件          → PluginsScreen
  自动化任务     → 自动化任务页（新增）
  网页版        → LocalWebScreen
  更多 ▸        → 本机引擎 / 远程主机 / 全部功能
```

「自动化任务」插在**插件和网页版中间**，用 `ChatGptScheduledTaskIcon`
（官方「闹钟 + 打勾」，到点自动的语义）。

**新增这个入口需要改 4 处**（照现有 `DrawerDestination` 的模式）：

| 位置 | 改什么 |
|---|---|
| `ui/shell/drawer/drawer_destination.dart:5` | 枚举加一个值（如 `scheduledTasks`） |
| `ui/shell/quick_panel.dart:11-19` | `icon` switch 加一项 → `ChatGptScheduledTaskIcon` |
| `ui/shell/quick_panel.dart:21-29` | `label` switch 加一项 → 新 l10n key |
| `ui/shell/home_shell.dart:234-242` | `_openDestination` switch 加一项 → 页面 |

注意 `DrawerDestination` 按 `Enum.name` 存储偏好（见
`quick_panel_state.dart` 注释），**改名会让已存偏好失效，只能新增不能改**。

## 五、两条硬提醒

1. **几何测试会红**：新布局下 600 高测试屏里会话行被功能区推出可视区。
   改法是让测试先 `scrollUntilVisible` 再量，**不是删测试**。golden 不重拍。
2. **推理强度别造新链路**：规则求值结果仍写 `ModelSelection.reasoningEffort`。
   别新起一个 store，否则又会「能选但没用」。