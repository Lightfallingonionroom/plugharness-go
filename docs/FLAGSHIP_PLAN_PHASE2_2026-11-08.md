# 旗舰施工单 v2（已验证版，2026-11-08）

> 本文件所有「实测」结论都来自真机截图像素采样（脚本 /tmp/px.py，纯 Python PNG 解码）与源码 grep，可复现。
> 同日早些时候写过一版未经完全验证的蓝图（已删除），其中两条结论被实测推翻，纠错记录见 §0。Flash 只按本文件执行。

---

## §0 纠错记录（未验证版错在哪）

| 未验证版结论 | 实测结果 | 判定 |
|---|---|---|
| "WallpaperBackdrop/AppBackdrop 挡住了聊天页颜色" | 聊天页真机截图像素 = **#212121 满屏**，侧栏 = **#171717**，composer = **#2F2F2F** | ❌ 作废。聊天壳配色**已生效**，背景层在 Scaffold 之下，挡不住它 |
| "对话列表全宽无限制" | `shapes.dart:88` 已有 `readingWidth = 720.0`，`chat_list.dart:784` 已用 `ConstrainedBox(maxWidth: readingWidth)`，gutter 16 | ❌ 作废。手机上 720 上限不触发，16dp 边距与官方 `min(100% - 32px, 920px)` 在窄屏等效 |
| "设置页颜色没变" | 设置页真机截图像素 = **#212835 / #1E222D / #1C1F28**（蓝调），非中性 #212121 | ✅ 证实。设置页仍是旧雾蓝系 |

---

## §1 已证实的根因（本轮核心发现）

**App 里存在两套并行配色系统，之前的改色只改了其中一套：**

| 系统 | 定义处 | 使用面（实测 grep 文件数） | 现状 |
|---|---|---|---|
| `ChatGptShellColors` | `chatgpt_palette.dart` | **仅 10 个文件**（聊天壳、侧栏、composer、用户气泡） | ✅ 已是官方灰阶 |
| `DshColors` + `DshPalette` + `NeutralTones` + accent | `palette.dart` / `semantic_colors.dart` / `surfaces.dart` / `accent.dart` | **233 个文件**（设置页、二级页、弹层、代码井、全部文字色） | ❌ 仍是雾蓝系 |

雾蓝系实锤数值（`palette.dart` NeutralTones.defaults）：`night #1C1F28`、`nightTop #1D222C`、`paper #E6E9F0`、`sheetDark #232832`、mist 档 `seedDark #97B1F0`（蓝）。

设置页走 `PageFrame → AppBackdrop`（渐变 nightTop→nightBottom + accent 光晕），Scaffold 背景是 `Colors.transparent`，所以用户看到"配色变都没变"——**变的只有聊天壳那 10 个文件，其余 233 个文件的颜色源头一个都没动**。

**修复策略（单点换血）**：不去改 233 个文件，而是把颜色**源头**（`DshPalette` 中性色常量 + `NeutralTones.defaults` 附带项 + 默认 accent）重定义为官方灰阶。所有下游自动变色。accent 机制保留（用户仍可选彩色主题），只把**默认档**换成官方中性。

---

## §2 施工步骤（Flash 执行，按顺序）

### F-A 官方灰阶写入 `palette.dart`（核心，一处改动全局生效）

深色（依据 `docs/openai-sdk-ui-spec.md` §3 官方 gray-* 表，该表来自 openai/apps-sdk-ui 源码实测）：

```
nightTop   = #212121   （渐变上下同色 = 视觉上纯色）
nightBottom= #212121
night      = #212121   （surface 主底，官方 --gray-200）
nightLowest= #171717   （sidebar / 更深一层）
nightLow   = #282828   （官方 --gray-250）
nightContainer = #303030 （elevated：卡片/输入框/弹层，官方 --gray-300）
nightHigh  = #303030
nightHighest = #393939 （官方 --gray-350）
paper      = #ECECEC   （primary text）
paperMuted = #AFAFAF   （secondary text，官方 --gray-700）
paperFaint = #8F8F8F   （tertiary text，官方 --gray-600）
paperGhost = #5D5D5D   （disabled，官方 --gray-500）
ruleDark   = #2F2F2F   （分割线）
outlineDark= #414141   （描边，官方 --gray-400）
shadowNight= #000000
```

浅色（同文档 light 列）：

```
mistTop    = #FFFFFF
mistBottom = #FFFFFF
mist       = #FFFFFF   （surface）
mistLowest = #FFFFFF
mistLow    = #F9F9F9   （surface-secondary）
mistContainer = #F3F3F3 （surface-tertiary）
mistHigh   = #ECECEC
mistHighest= #E5E5E5
ink        = #0D0D0D
inkMuted   = #5D5D5D
inkFaint   = #8F8F8F
inkGhost   = #AFAFAF
ruleLight  = #E5E5E5
outlineLight = #8F8F8F
```

`NeutralTones.defaults` 里不走 DshPalette 常量的附带项同步：
```
smoke      = #2F2F2F
sheetDark  = #303030   （弹层底，官方 elevated）
codeWellDark = #181818 （官方 --gray-100）
codeWellHeaderDark = #212121
codeWellBorderDark = #2F2F2F
inverseSurface = #ECECEC、onInverseSurface = #212121 （深色下互换语义）
terminal 系（#12151C/#262A33）可保留：终端卡本来就是"浅色模式也深底"的特殊件，与页面中性不冲突
```

### F-B 默认 accent 换成中性（`accent.dart`）

1. `AppAccent.preset()` 的兜底 `return mist` → `return graphite`（`accent.dart:269`）。只影响没存过偏好的用户；存过偏好的不受影响。
2. 把 `graphite` 档校准到官方值（`accent.dart:237-256`）：
   - `seed = #181818`（浅色主按钮，官方 background-primary-solid light = gray-900）
   - `seedDark = #F3F3F3`（深色主按钮，官方 dark = gray-950）
   - `pressed = #0D0D0D`、`pressedDark = #ECECEC`
   - `onSeed = #FFFFFF`、`onSeedDark = #0D0D0D`
   - `container = #F3F3F3`、`onContainer = #0D0D0D`、`containerDark = #303030`、`onContainerDark = #ECECEC`
   - `bubble = #0D0D0D0D`（alpha 5%，官方 user-message light）、`bubbleDark = #2F2F2F`
   - `glow = #FFFFFF`、`glowDark = #212121`（**光晕与页面同色 = 光晕不可见**，不用改 surfaces 的 alpha 逻辑，也不用删 AppBackdrop）
   - `tintChroma = 0`（纯中性）。**先写测试再改**：确认 `NeutralTones.of(tintChroma: 0)` 不产生 NaN/异常（其内部若有 `c / k` 类除法需保护）。
3. 预期连锁效果：`darkScheme.primary` 自动变 #F3F3F3；`app_theme.dart` 已有 `knobBlends` 逻辑处理"主色近白时开关钮换深墨"（石墨档当年就是为此设计），**预期无需改 app_theme**；改完跑开关相关测试确认。

### F-C 蓝色残留检查

- 链接/info 类若硬编码蓝 → 改官方 link 蓝 `#0285ff`（深）/ `#0169cc`（浅）。官方蓝色只用于链接与焦点环，**这一处保留蓝是符合官方的**，不要一刀切全去蓝。
- 焦点环/选中态用 `colorScheme.primary` 的 → 随 F-B 自动变中性，无需单独改。

### F-D 禁止事项（防"越搞越差"复发）

- **不要**动 `chat_screen.dart`、`sessions_drawer.dart`、`composer.dart`、`user_bubble.dart` 的结构（像素实测已正确）。
- **不要**动 `chat_list.dart` 的宽度逻辑。
- **不要**删 WallpaperBackdrop / AppBackdrop（F-A/F-B 后渐变自动退化为纯色；删了会破坏自定义壁纸功能）。
- **不要**重排侧栏/设置页的信息架构——用户说要再给布局参考图，但**新图没有送达本窗口**，重排必须等图。

---

## §3 验证方式（每步都要跑）

1. **单元测试钉死色值**（新增 `app/test/theme/official_palette_test.dart`）：
   断言 `NeutralTones.defaults` 的 night/paper/ruleDark 等 == 上述官方 hex；断言 `AppAccent.preset(null).id == 'graphite'`；断言 `graphite.seedDark == Color(0xFFF3F3F3)`；断言 `NeutralTones.of(tintChroma: 0)` 所有色值非 NaN。
2. `cd app && flutter analyze && flutter test`。golden 会大面积变化 → 用现成的 `.github/workflows/regen-all-goldens.yml`（dispatch-only）重生成。
3. **基线不回退**：通过数 ≥3437、失败 ≤12（这 12 个失败是上一轮已获用户豁免的存量项）。
4. **真机像素验收**：构建 → `tooling/sign-release.sh` 签名 → `pm install -r -d --user 0 --bypass-low-target-sdk-block` → screencap 三屏 → `python3 /tmp/px.py`：

| 屏 | 采样点 | 期望 |
|---|---|---|
| 设置页 | 页面底 | #212121 ±1，且 R≈G≈B（容差 ±3，证明无蓝调） |
| 设置页 | 卡片/弹层 | #303030 |
| 设置页 | 分割线 | #2F2F2F |
| 聊天页 | 页面底 | #212121（**回归确认，不许变**） |
| 侧栏 | 底色 | #171717（回归确认） |
| composer | 底色 | #2F2F2F（回归确认） |

5. 浅色模式同表：设置/聊天页底 #FFFFFF，分割线 #E5E5E5。

## §4 完成标准

- [ ] F-A/F-B 落地，`official_palette_test.dart` 全绿
- [ ] analyze 无新告警；测试通过数不低于基线（3437/12）
- [ ] golden 全量重生成并 commit
- [ ] 真机三屏像素采样全部命中期望值（把 /tmp/px.py 输出贴进交付报告作证据）
- [ ] APK 装机，用户目视验收设置页"不再是蓝灰色"

## §5 明确未决 / 无法完成的事

1. **布局比例、层级、排序**：用户承诺提供的新布局参考图本轮未到达，无法核对。等图后另出 F-E 施工单。
2. **字体**：用户明说不要求，跳过。
3. **"把 ChatGPT 的壳拆下来"**：不可行——官方壳是 Kotlin/Compose 编译进 9 个 dex 的产物，无法移植进 Flutter；但官方设计 token（#212121 系灰阶、418 个矢量图标、动效曲线）已全部提取入库，本方案就是"用官方图纸在我们的壳上重建"，效果等价于拆壳。
4. `tintChroma = 0` 在 `NeutralTones.of` 内部的数学安全性**未验证**，F-B 第 2 步要求先写断言测试再改值。
5. 本机 `run-as` 读 shared_prefs 失败（安装的 release 包 not debuggable），无法确认用户当前存的 accent 偏好是 mist 还是自定义色。**若用户存的是自定义色/壁纸取色，F-B 的默认档改动对其无效**，需用户在外观设置里手动切到"石墨"，或后续加迁移逻辑——这是当前无法在本机完成的验证。