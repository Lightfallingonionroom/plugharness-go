# 本轮的界面改动与验证状态

> 这份文件是给「人」看的交接单：改了什么、验到什么程度、还差哪一步。
> 与 `docs/changelog.md` 不同，它记录的是**未发版的工作**，发版前应删掉。

## 改了什么

对话页与侧栏按 ChatGPT 的信息层级重做，深浅两套都覆盖：

| 位置 | 之前 | 现在 |
|---|---|---|
| 对话页顶栏 | 三枚浮动玻璃胶囊（≡ / 标题 / 模型 / ✚） | 一条平顶栏：左侧 ≡，标题块（标题 + 状态副行），右侧模型与新对话；高度 56，左右 12 |
| 标题胶囊 | `symmetric(horizontal: 16)`，右侧被时钟占位叠加成 32 | `only(left: 16)`：右侧那 16 由 `HeaderScheduleCap` 的占位提供，两边都回到 16 |
| 空状态 | 鲸尾插画 + 按小时问候 + 4 条通栏建议 | 单句「有什么可以帮你？」，**没有**第二行副标题；建议 2×2 |
| 建议标签 | 「看看工作区有什么」「写个词频统计脚本」…（8 字，半行放不下） | 「看看工作区」「词频统计脚本」「新建 Node 项目」「rebase 或 merge」；放不下时仍回落单列，绝不截断 |
| 输入条 | 玻璃胶囊 | 实心圆角 + 1px 细线 |
| 侧栏 | 玻璃面板，字标 `DSH` | 平色面板，字标 `PlugHarness`，主色「新对话」，实心搜索条；品牌行与多选头共用 20/14/10/10 的盒子（「完成」正好落在「新对话」的位置） |
| 用户气泡 | 圆角全包 | 浅灰 + 右下角内收（`_UserBubbleShape`） |
| 抽屉遮罩 | 玻璃模糊 | 中性压暗，深色更暗 |

主题色板集中在 `app/lib/ui/theme/chatgpt_palette.dart`（`ChatGptShellColors` 主题扩展），页面/侧栏/输入条三种平色表面 + 扁平/输入条/侧栏三种 `GlassStyle`，由 `app_theme.dart` 接入。设置、引导、弹窗仍用原主题，没有被这层改到。

## 顺带修的既有问题

- Android 单测两处包名/应用名残留（`LauncherManifestTest` 期望 `DSH Go`、`RootBackendTest` 期望旧包名类）。
- `场景账户` 页面没登记进设置索引 → 补 `SettingsPageId.sceneAccounts` + 页面路由 + 归入「通用」分组。
- 三处布局溢出（`SelectionActionBar` 的按钮文字、`conversation_feature_grid` 的格子标签），都用 `Flexible` 兜住。
- 设置页「场景账户」行曾带副标题，行高被撑到 64 → 去掉（页面内已有说明），回到索引的 52 格。
- `shell_geometry_test` 找 `SessionSearchBar` 里的 `GlassSurface`，而它现在是实心 stadium → 改测承载它的 `Material`。

## 明确**没有**做的事

- **顶栏没有显示模型名。** 试过：新对话的标题位置放当前模型名。读着像 ChatGPT，但它让 `find.text` 在整个测试套件里变得有歧义（模型面板的卡片也叫同一个名字），连带 `model_sheet_test` 的 15 条断言全要改。收益不抵成本，已回退，标题仍是「新对话」，模型仍在输入条底部和胶囊上。
- **宠物（鲸鱼）没关。** 那是 `app/lib/pets/` 的独立功能，由 `performanceDefaultsProvider.petEnabled` 决定默认开不开，与空状态代码无关。默认值是产品决策，没有替你改。想关：设置 → 外观 → 宠物 → 不显示。
- **没有在真机点开验过这一版**：见下。

## 验到什么程度

- `flutter analyze` 通过（CI 里作为门禁，编译不过 2 分钟内就失败，不会再白跑 15 分钟）。
- 受影响的 golden 已重生成，测试 429 / 71 条全绿；浅色与深色都覆盖。
- 用 OCR 抽查过关键图：`empty_*.png` 是「有什么可以帮你？」单句 + 2×2；`drawer_*.png` 顶部是 `PlugHarness`。
- **真机**：装过一次（1.0.11，固定签名之前），看过侧滑抽屉、空状态、设置页；这一版（重签 + 2×2 + 单句标题）**还没装上**，卡在 MIUI 侧载确认框——需要解锁手机点「允许」。

## 发版密钥

固定发布密钥签名，取代每次 CI 现生成的 debug key（那会导致每次升级都必须先卸载、数据全丢）。

- keystore：`~/keys/dshgo-release.jks`（RSA 4096，30 年），密码 `~/keys/dshgo-release-password.txt`
- 已备份到 `/sdcard/Download/PlugHarness/keys/`
- 证书指纹：`SHA-256 2dfbbe7d06b1f29a32a35ceca27ac57aa287c5020ef413239d667097a3c4b16f`
- `app/android/key.properties` 指向它，该文件被 `app/android/.gitignore` 忽略；**密钥永不入库**
- CI 只产未签名/调试签名的包，落地后用 `tooling/sign-release.sh <apk> [out]` 重签

> ⚠️ 这把密钥丢了，就再也无法覆盖升级已装的 App（只能卸载重装）。务必另存一份到仓库之外的地方。
