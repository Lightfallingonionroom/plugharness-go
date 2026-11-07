# ChatGPT Android 客户端实测规格（从 base.apk 反编译读取）

来源：`base.apk`，`com.openai.chatgpt`，versionName `1.2026.300`，versionCode `2630015`。
原生 **Kotlin / Jetpack Compose**（9 个 dex、2298 个 res 文件），不是 Flutter、不是网页套壳。
工具：unzip + `androguard 4.1.4`（`AXMLPrinter` 解二进制 XML，`ARSCParser.get_res_configs`
解 typed value）。所有下列数值均为**从 APK 二进制解出的真实值**，不是目测估计。

解析产物（可复现）：`/tmp/cgpt/anim_final.json`、`/tmp/cgpt/drawable_final.json`。

## 1. 动效曲线（res/interpolator）

Compose 的 `AnchoredDraggableState` / `settle(animationSpec)` 侧栏用 M3 token：

| token | 控制点 (x1,y1,x2,y2) | 用途 |
|---|---|---|
| `m3_sys_motion_easing_standard` | **0.2, 0, 0, 1** | 常规进出 |
| `m3_sys_motion_easing_standard_accelerate` | **0.3, 0, 1, 1** | 退出加速 |
| `m3_sys_motion_easing_standard_decelerate` | **0, 0, 0, 1** | 进入减速 |
| `m3_sys_motion_easing_emphasized_accelerate` | **0.3, 0, 0.8, 0.2** | 强调型退出 |
| `m3_sys_motion_easing_emphasized_decelerate` | **0.1, 0.7, 0.1, 1** | 强调型进入 |
| `m3_sys_motion_easing_linear` | **0, 0, 1, 1** | 线性 |
| `fast_out_slow_in` | **0.4, 0, 0.2, 1** | 系统插值器 |
| `fragment_fast_out_extra_slow_in` | `M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1` | fragment 转场 |

## 2. 时长（res/anim、res/animator）

| 动作 | 时长 | 附带 |
|---|---|---|
| fragment open / close | **300ms** scale 0.85→1 / 1→0.9 | alpha 分段 50ms、66ms |
| fragment fade | **150ms** | 0→1 / 1→0 |
| bottom sheet in | **250ms** | 位移 20%p + alpha 0→1 |
| bottom sheet out | **200ms** | 位移 0→20%p + alpha 1→0 |
| M3 fade enter | **400ms** | alpha + scale 0.8→1 |
| M3 fade exit | resource `0x7F0B0021` | alpha 1→0 |
| ABC grow/shrink | **220ms**(scale) / **150ms**(alpha) | scale 0.9↔1 |

## 3. 圆角与配色（res/drawable，私有资源）

| 资源 | 圆角 | 填充色 |
|---|---|---|
| `search_background` | **22dp** | **#FF343338** |
| `search_background_xl` | **26dp** | **#FF343338** |
| `surface_background` | **20dp** | **#FF1F1E20** |
| `surface_background_small` | **28dp** | **#FF1F1E20** |
| `button_background` | **20dp** | **#FF343338** |
| `pi2_sandbox_options_dialog_bg` | **28dp** | — |
| `m3_bottom_sheet_drag_handle` | **2dp** | — |
| `exo_rounded_rectangle` | **16dp** | — |
| `tooltip_frame_*` | **2dp**（complex `0x201`） | — |

注意：深色主底是 **#1F1E20**，卡片/输入框层级是 **#343338**——
与本仓库 `chatgpt_palette.dart` 当前用的 `#212121 / #303030` 存在差异，可直接对齐。

## 4. 侧栏结构（dex 字符串实证）

`CHATGPT_SIDEBAR_MENU_ITEM_*` 枚举实际包含：
`LIBRARY / PROJECTS / NEW_PROJECT / AGENTS / MEMORY / PEOPLE / HEALTH / MEETINGS /
MESSAGES / FINANCES / SHOPPING / CALCULATORS / IMAGE_HOME / CHATGPT_ROW /
CUSTOMIZE / SETTINGS / UPGRADE / NEW_CHAT / NEW_NOTE / HELP_CENTER / ASSISTANT / ACTIONS / PLUGINS`

侧滑驱动：`AnchoredDraggableState`、`settle(animationSpec)`、`SpringSpec`、
`positionalThreshold` / `velocityThreshold` / `snapTo()`、`ViewDragHelper`、
`FlingResult(distanceCoefficient=…)`、`VelocityTracker`。
→ 官方是**锚点 + spring 落位**，不是逐帧手写线性跟随。

## 4b. 图标集（res/drawable/ds_*.xml，48 个）

官方不用 Material/Phosphor，而是自绘 `ds_<name>_regular_24` 系列：
全部 **24×24dp、viewport 24×24、`fillColor #FF000000`、1–7 条 path**。

实读清单（部分）：`ds_brain`（思考）、`ds_camera`（拍照）、`ds_photo` /
`ds_photo_on_tilted_square`（照片）、`ds_folder`（文件）、`ds_pencil` /
`ds_paintbrush_on_pencil`（新建/编辑）、`ds_microphone(_fill)`、
`ds_voice_button`（语音键）、`ds_circle_stop_fill` / `ds_stop_fill`（停止）、
`ds_chat_bubble`（对话）、`ds_share_android`（分享）、`ds_plane_up_right`（发送）、
`ds_globe`、`ds_codex`、`ds_terminal`、`ds_book`、`ds_bar_chart`、
`ds_wrench`、`ds_paint_palette`、`ds_personalization`、`ds_star_of_life`、
`ds_openai_blossom`、`ds_suitcase`、`ds_music_note`。

**本仓库落地方式**：把这 27 个常用角色的 path 转成
`app/tool/icons/openai/*.svg`（24×24 viewBox），`tool/make_icon_font.py` 新增
`openai()` 源（按 `oaFoo` 前缀分派，24→256 网格缩放），重新生成
`assets/fonts/DshIcons.ttf` 与 `dsh_glyphs.dart`；`AppIcons` 的角色
（send / voice / camera / gallery / files / share / edit / newChat / engine /
web / model / theme / chat / settings …）改指向 `DshGlyphs.oa*`。
这样所有按钮一次换装，不需要逐个改 widget。

设置页 `SettingsIcon` 原本给每个图标套彩色圆底（`colors.identity[tint]`），
官方是**无底色单色线性图标**，已去掉圆底。

## 5. 对本仓库的落地清单

1. `AppMotion` 的曲线改为上表实值（当前是自定义 `Easing.standard`）。
2. 侧栏/输入/卡片圆角改为 22 / 20 / 28dp；深色主底 `#1F1E20`、卡片 `#343338`。
3. 侧滑从 `RawGestureDetector` + `AnimationController.value` 改为
   `SpringSimulation` 落位 + 位移阈值 + 速度阈值（等价于 AnchoredDraggable 的
   positional/velocity threshold），拖动期间禁止玻璃模糊采样。
4. 时长按 300 / 250 / 200 / 150ms 分档。
5. 侧栏功能项按第 4 节枚举扩充并分组。

## 边界说明

- Compose 的 `dp` 常量编译进 dex，不以 `res/dimen` 形式存在；文件中「宽高/边距」
  的精确值需反编译 dex 才能拿到，本轮未做，不编造。
- 颜色取自 XML drawable 的实心 shape；Compose `Color(...)` 运行期常量同样在 dex 内。
- 此 APK 为官方客户端，源码非公开；本文件是**二进制资源级实测**，不是源码抄录。