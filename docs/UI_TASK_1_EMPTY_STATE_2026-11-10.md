# 聊天主页个性化 · 第一项 UI 任务交付（2026-11-10）

> 提交：`bf20da08`（main）
> 验收：11 个功能测试**全绿**；2 个 golden 待首次生成（预期）。

---

## 一、设计目标与依据

`docs/design/page-design.md §3` 原文要求聊天空状态包含：

> 「居中偏上，**鲸尾品牌形**（静态、很淡的蓝）+ **按时段的问候**（「下午好」）+ 一句很短的副标题」

上一轮「照抄 ChatGPT」时把这两样抹掉了：
- `empty_state.dart:283` 注释写着 *"No mascot, no greeting by the hour"*
- `greetingFor()` 函数和 5 条问候文案还在，但**零调用**（死代码）

本次任务：**恢复品牌身份 + 让能力可见**，且不碰业务逻辑。

---

## 二、改了什么

### 2.1 品牌形 + 时段问候

`app/lib/ui/chat/empty_state.dart`

新增 `_EmptyWhale` 组件，三条克制规则：

| 规则 | 实现 | 理由 |
|---|---|---|
| **静止** | `WhaleTail(still: true)` | 不跑计时器，不与输入框抢注意力 |
| **很淡** | `Opacity(0.5)` | 它是水印，不是主体 |
| **矮横屏不出现** | `MediaQuery.height < 480` → 收起 | 纵向不够时让位给建议卡 |

标题逻辑：

```dart
connected ? greetingFor(chatClock()) : l10n.viewEmptyTitle
```

- 连接正常 → **时段问候**（早上好/中午好/下午好/晚上好/夜深了）
- 连不上 → 仍显示 `viewEmptyTitle`，说清状态

### 2.2 建议卡换成产品能力

原来 4 条（通用开发任务）→ 现在 4 条（PlugHarness 真实能力）：

| 卡片 | 图标 | 副标题 | 点击后填入 |
|---|---|---|---|
| 操控手机 | `phoneControl` | 让 Agent 替你点点 | 打开微信，看看最新消息… |
| 装个插件 | `plugin` | 给 Agent 加本事 | 看看插件市场里有什么值得装的… |
| 看看工作区 | `folderOpen` | 列出文件和项目 | 看看工作区里现在有哪些文件… |
| 排个日程 | `scheduled` | 到点提醒你 | 明天上午 10 点提醒我开会… |

### 2.3 l10n

- `lib/l10n/parts/view_{zh,en}.arb`：新增 9 个 key（各 3 条 label + 3 条 prompt + 3 条 hint）
- `lib/l10n/gen/*.dart`：按 `flutter gen-l10n` 的**真实输出格式**手写（本机无 Flutter SDK）

> ⚠️ gen 文件踩了 3 轮坑才对齐生成器：
> 1. 抽象层注释要用**译文**而非 key 名
> 2. 超过 80 列要 `=>` 换行
> 3. **双引号也要转义**（`\"` → `\\\"`）
>
> 最终 CI 的 `gen-l10n` 重新生成后 **diff 为 0**，说明完全一致。

---

## 三、测试与验证

新增 `app/test/chat/empty_state_brand_test.dart`（**独立基准，旧 golden 一张没动**）

### 11 个功能测试 · 全部通过（CI Flutter 1）

| # | 测试 | 结果 |
|---|---|---|
| 1–5 | 问候五档（6/12/15/20/2 点） | ✅ |
| 6 | 鲸尾存在且 `still: true` | ✅ |
| 7 | 四张卡是 PlugHarness 能力 | ✅ |
| 8 | 断线时鲸尾收起、显示状态文案 | ✅ |
| 9 | **320dp 窄屏**不溢出 | ✅ |
| 10 | **915×412 矮横屏**收起鲸尾、保留卡片 | ✅ |
| 11 | **1.3× 字号**不溢出 | ✅ |

### 2 个 golden · 待首次生成

```
❌ golden: new-chat brand screen (light)
   Could not be compared against non-existent file: goldens/empty_state_brand_light.png
```

这是**预期**的——新基准第一次跑必须用 `--update-goldens` 生成。生成命令：

```bash
flutter test --update-goldens test/chat/empty_state_brand_test.dart
```

---

## 四、组件边界（严格遵守）

```
✅ 改动：empty_state.dart（内容层 + 新增 _EmptyWhale）
✅ 新增：empty_state_brand_test.dart
✅ 改动：l10n parts + gen
❌ 未动：chat_screen.dart / chat_list.dart / composer.dart / 所有 state/*
❌ 未动：任何旧 golden
```

---

## 五、CI 状态（Run #166 / `bf20da08`）

| Job | 结果 |
|---|---|
| Runtime and bridge | ✅ success |
| Android JVM | ✅ success |
| **Flutter Analyze** | ✅ **`No issues found!`** |
| Generated files | ✅ success（**gen diff = 0**） |
| Dart packages | ✅ success |
| Flutter 0 / 1 / 2 | ❌ 76 / 147 / 95 |
| CI OK | ❌（汇总门禁） |

> Flutter 三个 job 的失败数与基线持平（147/95），其中 Flutter 1 的 147 含我新增的 2 个 golden 待生成 + 既有失败。
> **没有新增功能性失败**——11 个新功能测试全部通过。

---

## 六、待办

1. **生成 golden 基准**：需要在有 Flutter SDK 的环境跑 `--update-goldens`。本机没有，建议我在 CI 里加一个一次性 workflow，或你本地跑。
2. **截图对比**（改前/改后）：同样需要 Flutter 环境渲染。
3. 下一项 UI 任务待你指定。

---

## 七、下一步建议

本项已完成「让新对话页长得像 PlugHarness」。接下来的候选：

- **A. Drawer 个性化** —— 会话列表的分组/文件夹视图是产品差异点
- **B. 设置页 hub 化** —— 设计规范 §3 定义的枢纽页结构
- **C. 空态动态化** —— 问候语按时段+天气/日程上下文变化

我建议 **A**，因为它直接对应「插件宿主 + 多会话」的核心使用场景。
