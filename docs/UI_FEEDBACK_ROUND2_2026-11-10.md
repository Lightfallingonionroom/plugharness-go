# 实机 UI 反馈修复 + Issue #5 交付报告（2026-11-10）

> 起点 `f6bba727` → 终点 `fbee0840`（main）
> 报告日期：2026-11-10

## 一、你提的 5 个问题：完成情况

| # | 问题 | 状态 | 说明 |
|---|---|---|---|
| 1 | 侧边栏「插件/引擎/设置」和「对话」一起滑 | ❌ **回退了** | 改法错了，见 §4 |
| 2 | 主题色能选但**颜色不对** | ✅ **修好了根因** | 见 §2 |
| 3 | 删掉 P3 独立主题页，设置页直接改 | ✅ 完成（上一轮） | `_ThemeRow` 就地展开 |
| 4 | 原生二级页渐变 → 纯色 | ✅ 完成 | 见 §3 |
| 5 | UI 动态适配全部颜色 | ✅ 完成 | 见 §2 |

Issue #5（插件运行时兼容性治理）：✅ 判断层完成，UI 接线未做（见 §5）。

## 二、「主题色不对」的根因（两个，都是真的）

### 2.1 对话壳的颜色和强调色**完全无关**

`app/lib/ui/theme/chatgpt_palette.dart` 里：

```dart
/// [accent] is kept for the caller's convenience and deliberately unused.
factory ChatGptShellColors.light(AppAccent accent) => ChatGptShellColors(
  page: const Color(0xFFFCFCFC),      // 硬编码
  sidebar: const Color(0xFFF4F4F4),   // 硬编码
  ...
```

注释白纸黑字写着 `deliberately unused`。所以选任何颜色，页面、侧边栏、
输入条、分隔线**一格都不动**，只有按钮和高亮变。

**修法**：`page` / `sidebar` 改为从 `NeutralTones.forAccent(accent)` 取，
和二级页的 `DshSurfaces.backdropTop` 同源。

### 2.2 中性色阶的染色公式对纯灰恒等于零

`app/lib/ui/theme/oklch.dart` 的 `retint()`：

```dart
return o.copyWith(c: o.c * chromaScale, ...)
```

官方灰阶是 `R == G == B`，`Oklch.c` 是 **0**。`0 × 任何数 = 0`。
所以「把中性色阶转到 accent 的色相」这件事，**从来没有发生过**。

**修法**：给一个 0.014 的彩度底噪。实测效果：

| 配色 | 侧边栏（原 `#F9F9F9`） | 深色页（原 `#212121`） |
|---|---|---|
| graphite | `#F9F9F9`（**一格不动**） | `#212121`（**一格不动**） |
| official_blue | `#F1FBFF`（冷蓝） | `#1B2226` |
| official_lime | `#FFF8F0`（暖黄） | `#25201B` |
| official_pink | `#FFF6FA` | `#261F22` |

`graphite` 走 `tintChroma == 0` 短路，`NeutralTones.of()` 直接返回
`defaults` 本体（`identical` 成立，`palette_contrast_test` 那条契约保住）。

### 2.3 顺带修的：官方十色在设置页点不中

上一版把官方十色塞进了 `PalettePicker` 那一行（11 个色点）。390 宽下
每个只剩 21 px，最后两个落在视口外——`appearance_page_test` 11 条全红
（`tap()` 直接 miss）。

**修法**：
- `PalettePicker` 回到 `AppAccent.presets`（6 个 + 自定义），单行等距，
  几何契约成立；
- 新增 `OfficialAccentGrid`：官方十色用 `Wrap` 网格，每个色点保住 30 px，
  折行不挤。

**它最终放在「更多外观」的完整页里，不在设置首页的展开区。** 我一开始
把它放在设置页展开区，结果把 `ThemeModePicker` 挤出了视口
（`appearance_page_test` 的「深色」找不到）。设置页就地展开的那一块
高度预算装不下第二排色点，完整页是滚动页，装得下。

**所以你实机看到的「十色选不中」现在的状态**：bug 本身（`preset()` 只查
`presets`、静默回退 graphite）在 `d1f45d29` 就修好了，十色能选中；
入口在「设置 › 外观 › 更多外观」的配色区。如果你希望它直接出现在设置首页
展开区，需要把明暗/配色/十色整块重新排版——那是下一轮的事。

## 三、渐变改纯色

先说一个关键事实：**`mistTop == mistBottom == 0xFFFFFFFF`，
`nightTop == nightBottom == 0xFF212121`**。所谓「竖向渐变」两个端点根本
是同一个颜色——你看到的渐变**不是渐变，是两团光晕**（右上主色、左下暮紫）。

所以改法不是「删掉 LinearGradient」，是**关掉光晕**：

- `AppBackdrop.glow` 默认 `true` → `false`
- `BackdropVeil` / `BackdropVeil.top` 的 `glow` 同步改为 `false`
  （否则顶栏/底栏遮罩会残留一条色差）
- `_BackdropPainter._gradient()`：两端同色时直接 `drawRect` 平涂，
  省掉 shader；两端不同色仍能画真渐变（给未来主题留的口子）

现在二级页、对话页、侧边栏是同一个底色。

## 四、侧边栏滚动：我改错了，已回退

**做过的尝试**：品牌行和搜索框保持固定，把功能区、工作区切换、过滤器
并进 `ListView` 的 header，一个手势带起整列。

**结果**：`drawer_geometry_test` **7 条全红**。
`DrawerFolderHeader` 和 `SessionTile` 直接找不到——600 高的测试抽屉里，
header 把文件夹挤出了列表的构建窗口。空态那次更糟（`_Centered` 是
`SingleChildScrollView`，套进 `SliverFillRemaining` 后工作区空态渲染成空白，
`issue52_empty_workspace_test` 12 条红）。

**处理**：`fbee0840` 把两个抽屉文件整体恢复到 `f6bba727`。

**为什么不再这一次硬修**：这不是「加个参数」能解决的。真正要做的是
重新设计抽屉的高度预算——哪些行固定、滚动容器边界在哪、空态在滚动体里
怎么居中。这个需要单独一轮，配一组新的几何测试。**我不想为了让你看到
「改了」而交付一个 600 高屏幕上文件夹消失的侧栏。**

## 五、Issue #5：插件运行时兼容性治理

### 交付物

- `app/lib/state/plugin_runtime_compat.dart`（432 行，纯 Dart，只 import `dart:convert`）
- `app/test/state/plugin_runtime_compat_test.dart`（22 条，**本地 `dart test` 全绿**）
- `docs/PLUGIN_RUNTIME_COMPATIBILITY.md`

### 触发案例定位到真实代码

| 报错 | 来源 | 是什么 |
|---|---|---|
| `toolFilter is no longer supported` | `@deepseek-ai/dsh-tool-subagent/lib/index.js:355` | 运行时硬性 `throw`：`for (const field of ["persona","toolFilter"]) if (Object.hasOwn(config, field)) throw ...` |
| `tool-subagent-list-agents: never started` | `@deepseek-ai/dsh-agent-preset-registry/lib/index.js:162` | Agent Preset 注册表里某一行从未挂载 |

### 设计要点

**八类故障，只有 `unverified` 不拦。** 老插件普遍没有兼容性声明，
全判死等于毁掉生态，全放行等于假装验证过。所以：放行 + 明说「无法验证」。

**已删除字段是数据表，不是 if 分支：**

```dart
static const all = <RemovedPluginFields>[
  RemovedPluginFields(field: 'toolFilter', plugin: 'dsh-tool-subagent', replacement: '...'),
  RemovedPluginFields(field: 'persona',    plugin: 'dsh-tool-subagent', replacement: '...'),
];
```

这张表**已用真实运行时核对**（`/tmp/verify_removed_fields.py` 直接读
`dsh-tool-subagent/lib/index.js` 的 throw 语句，比对字段集合、措辞、
以及运行时推荐的 `agentPreset`）。运行时改了而表没跟上，脚本会失败。

**迁移是显式契约，默认一个都不做。** `apply()` 只在形状完全匹配时返回
新 map，绝不改入参。`toolFilter` / `persona` **故意没有迁移器**——运行时
要求把它们搬进 Agent Preset，而「把工具白名单搬进预设」会改变 agent
能做什么，这不是工具该替用户做的决定。

### 没做的部分

**判断层还没有接到 UI 上。** 要真正出现在你面前，还需要：
1. 插件列表/详情页调 `checkPluginAtRuntime()`；
2. Runtime 报错经 `classifyPluginRuntimeError()` 转成诊断卡；
3. 迁移确认弹窗。

这三步要动 UI 和 bridge，是独立一轮。我没有在报告里假装做完。

## 六、CI 状态

| Job | 结果 |
|---|---|
| `flutter analyze` | ✅ **No issues found!** |
| `l10n gen diff` | ✅ **归零** |
| `Android JVM` | ✅ **success**（APK 能构建） |
| `Runtime and bridge` | ✅ success |
| `Dart packages` | ✅ success |
| `Generated files` | ✅ success |
| `Flutter 0/1/2` | ❌ 失败（详见下） |

Flutter 测试失败分三类：

1. **golden 失败** —— 按你定的 C 方案不重拍。主题变了，基准图必然对不上。
2. **`palette_contrast_test` 79 条** —— `tertiary #8F8F8F` 对白底实测
   **3.23**，阈值 4.5。我算过：`floor=0`（改动前）也是 3.23，**不是我的
   改动造成的**，是 `4ed2bebd`「全壳接入官方中性灰阶」那次就埋下的。
   它之前没在 CI 里出现，是因为**测试分片按文件排序号取模**，我新增了一个
   测试文件，把后面所有文件的 `NR` 推移了 1 位，它才被分到会执行的那一片。
3. **其余**（`plugin_controls_parity` 26、`parallel_setup_geometry` 24 等）
   —— 都逐项和 `f6bba727` 的失败数比对过，数量相同，是既存失败。

**我没有为了让 CI 变绿去改这些测试的期望值。** `tertiary` 那 79 条是一个
真实的可访问性缺陷（三级文字在浅色底上不达标），该修的是 `dusk` 的色值，
那是设计决策，不该由我顺手改。

## 七、这一轮我犯的错（如实记）

1. **`NeutralTones` 没导入** `chatgpt_palette.dart` → `Android JVM` 红了一次。
2. **空态套了两层滚动** → `issue52_empty_workspace_test` 12 条红。
3. **侧栏 header 挤掉文件夹** → 7 条红，最终回退。
4. **`$removed.field` 少花括号** → 22 条测试里 1 条红（`classifyPluginRuntimeError`
   永远返回 null）。改的时候把「属性访问必须保留花括号」和「后面跟空格
   可以去掉」混为一谈了。
5. **l10n en gen 手写成两行** → gen diff 红了一次（生成器不按列宽折行）。

## 八、下一步建议

按优先级：

1. **侧边栏滚动**（你提的第 1 个问题，唯一没解决的）—— 需要单独一轮，
   先设计高度预算，再写新的几何测试。
2. **Issue #5 的 UI 接线** —— 让兼容性诊断真的出现在插件页。
3. **`tertiary` 对比度**（79 条测试）—— 设计决策：调 `dusk` 还是放宽阈值。
4. **golden 重拍** —— 等你确认视觉方向后一次性做。