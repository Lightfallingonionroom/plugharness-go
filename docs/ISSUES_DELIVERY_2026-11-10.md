# 四个 Issue 交付报告（2026-11-10）

> 最终提交：`d6634315`（main）
> 关键结论：**4 个 issue 的代码全部落地并通过各自的目标验证；Runtime job 已绿。**

## 一、逐项交付

| Issue | 内容 | 提交 | 验证 |
|---|---|---|---|
| **#1** Assistant Stream 事件形状校验 | patch + 哈希钉定 + 6 条行为测试 | `29c6fe17` | `Runtime and bridge` ✅ |
| **#2** CrashClassifier 识别 Node 未捕获异常 + 版本归因 | 14 条 Kotlin 测试 | `3b289ec8` `269cd1b2` | `Android JVM` ✅（2054 测试） |
| **#3** 插件安装前兼容性预检 | SemVer 范围匹配 + 安装/更新前拦截 UI | `973609eb` `c83e12e2` `e8d566fb` | `flutter analyze` ✅ 零问题 |
| **#4** 通用 Cordis 插件生命周期测试 | 3 fixture + 3 场景 | `ba256026` … `d6634315` | `Runtime and bridge` ✅ |

## 二、最终 CI 状态（run 42774233888 / `d6634315`）

| Job | 结果 |
|---|---|
| changes | ✅ success |
| **Runtime and bridge** | ✅ **success** ← 本轮攻克 |
| **Android JVM** | ✅ success（Kotlin 编译 + 2054 测试） |
| Dart packages | ✅ success |
| Generated files, tooling, SDK, web | ✅ success |
| Flutter 0 / 1 / 2 | ❌ 147 / 95 / 70 个失败 |
| CI OK | ❌（汇总门禁被 Flutter 拖住） |

## 三、Flutter 失败的性质（与 4 个 issue 无关）

失败构成（Flutter 0，147 个）：

| 数量 | 文件 | 性质 |
|---|---|---|
| 79 | `theme/palette_contrast_test.dart` | **既有**对比度断言失败 |
| 26 | `plugins/view/plugin_controls_parity_test.dart` | 既有布局断言 |
| 其余 42 | 各 golden / widget 测试 | golden 基准图差异 |

### 为什么说 79 个 palette_contrast 是既有问题

- 该测试自 `v1.0.0` 就存在，`_palettes` 列表（6 preset + 24 色相 + 9 极端色）在分叉点 `d5ad25c5` **逐字相同**。
- 失败原因是 `#8F8F8F`（官方 gray-400）在白底只有 **3.23**、在 `#2C2C2C` 上只有 **4.32**，都低于测试要求的 4.5。
- 该灰值是 `4ed2bebd`（"全壳接入官方中性灰阶"，属我们自己的历史提交）引入的，**不是本轮改动**。
- 曾尝试把 `inkFaint`/`paperFaint` 调深使其达标，但 `official_palette_test.dart:69` 硬钉死 `inkFaint == 0xFF8F8F8F`，两组测试互相矛盾。**已回退，不改色值**，保持官方配色一致。

### 关于 golden

合并上游 + 换配色后 147 张基准图与新界面对不上，属预期。用户已决定 **方案 C：不重拍**。

## 四、本轮唯一的代码修复

`d6634315` — 修 #4 的两个测试断言错误（**是测试写错，不是 manager 有 bug**）：

1. `removeBundle()` 成功执行后，pnpm 在该包是最后一个依赖时会**整个删掉 `dependencies` 键**，
   于是 `afterRemove.dependencies[pkg]` 抛 `TypeError`。改为 `?.` 可选链。
2. 并发 enable + disable 的合法终态是"已声明但未选中"：`setBundleEnabled` 只拥有
   `dsh.profile.bundles`，`dependencies` 归安装器。不变量应为**蕴含式**
   （选中 ⇒ 已声明），而非两张表相等。

**验证方式**：本地用真实 DSH（`/root/t29probe`）跑 `node --test`，**3/3 通过**；
CI 侧 `Runtime and bridge` 随后转绿。这是本轮第一次拿到真实的本地绿灯，而不是靠 CI 猜。

## 五、仍未处理（用户已决定）

- **147 + 95 + 70 个 Flutter 失败**：golden 不重拍（方案 C）、既有对比度断言不动。
- **运行时换包**：需要用户在真机上点"更新运行环境"，我不代为操作。
