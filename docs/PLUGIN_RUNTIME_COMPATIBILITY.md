# 插件运行时兼容性治理（Issue #5）

> 实现：`app/lib/state/plugin_runtime_compat.dart`
> 测试：`app/test/state/plugin_runtime_compat_test.dart`（22 条，本地 `dart test` 全绿）
> 运行时核对：`/tmp/verify_removed_fields.py`（读真实 DSH 源码，OK）

## 这个 Issue 解决的是哪一层

项目里已经有两条相邻的能力，本 Issue 不重复它们：

| | 时机 | 数据源 | 结论 |
|---|---|---|---|
| **#3** `plugin_compat.dart` | 安装**前** | 市场索引的 `engines.dsh` | 能不能点「安装」 |
| **#4** `cordis-lifecycle.test.mjs` | 装完之后 | 真实 DSH + profile | 装/启/停/卸是否留下垃圾 |
| **#5 本模块** | 安装**后、注册时、会话创建时** | 插件自己的 `package.json` + profile 配置 + Runtime 真实报错 | 这个插件能不能在这个 Runtime 上真的起来 |

三者互补：#3 挡住「明确装错版本」，#4 保证「装完能干净卸掉」，#5 回答
「装上了为什么起不来、是谁的错、怎么退」。

## 触发案例（已定位到真实代码）

用户装了 `mmparko/dsh-purge`（README 声明目标 DSH `0.2.0-rc.2`）后，设置 →
内置插件 → 会话插件报：

```
tool-subagent-list-agents: never started
tool-subagent: toolFilter is no longer supported;
  configure persona and tool plugins in an Agent Preset
  and select it with agentPreset (spawn only)
```

两句话分别来自两个地方，代码位置已核实：

| 报错 | 来源 | 含义 |
|---|---|---|
| `toolFilter is no longer supported` | `@deepseek-ai/dsh-tool-subagent/lib/index.js:355` | 运行时**硬性 throw**：`for (const field of ["persona","toolFilter"]) if (Object.hasOwn(config, field)) throw ...` |
| `never started` | `@deepseek-ai/dsh-agent-preset-registry/lib/index.js:162` | Agent Preset 注册表里某一行从未挂载成功 |

也就是说：这不是「插件坏了」的单点问题，而是**插件按旧契约写配置、新运行时
按新契约拒绝**。报错以两行红字呈现，没有插件名、没有字段路径、没有版本，
用户无从下手。这正是本模块要补的。

## 设计

### 1. 故障分七类，只有一类不拦

`PluginRuntimeFault`：

| 值 | 拦截？ | 什么时候 |
|---|---|---|
| `missingPackage` | ✅ | 包不在 `node_modules`，或入口模块找不到 |
| `unreadableManifest` | ✅ | `package.json` 不是合法 JSON，或没有 `name` |
| `hostApiMismatch` | ✅ | 按旧 Host API 写的 |
| `removedConfigField` | ✅ | 配置里有运行时已删除的字段（`toolFilter` / `persona`） |
| `missingAgentPreset` | ✅ | 引用的 Agent Preset 没启动 |
| `unresolvedPluginReference` | ✅ | composition 引用的插件 id 解析不到 |
| `registrationFailed` | ✅ | 插件自己注册时抛错 |
| `unverified` | ❌ | **什么都没声明**：不知道，所以不假装知道 |

`unverified` 是唯一不拦的一类，这是刻意的。老插件普遍没有兼容性声明，
把它们全判死等于毁掉整个第三方生态；把它们全放行等于假装验证过。所以：
**放行 + 明说「无法验证」**。

### 2. 已删除字段是数据，不是 if 分支

```dart
static const all = <RemovedPluginFields>[
  RemovedPluginFields(field: 'toolFilter', plugin: 'dsh-tool-subagent', replacement: '...'),
  RemovedPluginFields(field: 'persona',    plugin: 'dsh-tool-subagent', replacement: '...'),
];
```

加下一个被删字段只改一行。这张表**已用真实运行时核对**：
`verify_removed_fields.py` 直接读 `dsh-tool-subagent/lib/index.js` 的 throw
语句，比对字段集合、报错措辞、以及运行时推荐的替代字段 `agentPreset`。
运行时改了而表没跟上，脚本会失败，不会静默漂移。

### 3. 报错归类：保留原文，给出人话

`classifyPluginRuntimeError()` 把运行时那句没有主语的 `Error` 变成：

- **哪个插件**（`plugin`）
- **哪一类**（`PluginRuntimeFault`）
- **哪个字段**（`path`，如 `config.toolFilter`）
- **怎么办**（`message`，中文，指名 `Agent Preset` + `agentPreset`）
- **原文**（`rawError`，逐字保留，供诊断日志/提 issue）

认不出来的错误返回 `null`，**不硬猜**。猜错比不猜更糟：会把人引向错误的修法。

### 4. 迁移是显式契约，默认一个都不做

```dart
class PluginConfigMigration {
  Map<String, Object?>? apply(Map<String, Object?> config);
}
```

`apply()` 只在**形状完全匹配**时返回新 map，否则 `null`。规则：

- `fromField` 必须在、`toField` 必须不在（两者都在 = 有歧义，拒绝而不是覆盖）
- 返回新 map，**绝不改传入的 map**
- `toolFilter` / `persona` **故意没有迁移器**：运行时要求把它们搬进 Agent
  Preset，而「把工具白名单搬进预设」会改变 agent 能做什么。这不是工具该替
  用户做的决定，所以只报错 + 给指引，不代劳。

目前唯一的迁移器是 `preset` → `agentPreset`（纯改名，语义不变）。

### 5. 隔离：一次检查只读一个插件的输入

`checkPluginAtRuntime()` 的每条结论都只依赖 `(该插件的 manifest, 该插件的
config, providedPlugins)`，没有跨插件共享状态，也没有「第一个失败就中断」。
测试 `one bad plugin does not poison the others` 钉住这条。

## 与安全边界的关系

本模块**只读**。没有文件写入、没有 `pnpm` 调用、没有改 profile。唯一能改配置
的入口是 `PluginConfigMigration.apply()`，返回新 map，由调用方决定是否落盘。

明确不做：

- 不自动删配置字段（安全失败优先）
- 不为了「让它跑起来」而放宽工具权限
- 不把未知错误猜成已知类别
- 不为单个插件写特例

## 验收对照

| Issue 验收项 | 落在哪 |
|---|---|
| 统一兼容性元数据 | `PluginCompatibilityDeclaration`（`dsh.compatibility` 优先，回退 `engines`） |
| Runtime 配置/API 预检 | `checkPluginAtRuntime()` |
| 有边界的迁移（备份/差异/回滚，fail closed） | `PluginConfigMigration`（纯函数、形状严格匹配、不改入参） |
| 插件级故障隔离 | 每条检查独立输入；`one bad plugin does not poison the others` |
| 自动化测试矩阵 | `plugin_runtime_compat_test.dart` 22 条，本地全绿 |
| 文档 + 职责边界 | 本文档 §「这个 Issue 解决的是哪一层」 |

## 尚未接入的部分（下一步）

本模块是**判断层**，还没接到 UI 上。要真正出现在用户面前，还需要：

1. 在插件列表/插件详情页调 `checkPluginAtRuntime()`，把 `unverified` 显示成
   「未验证兼容性」而不是绿色对勾；
2. 把 Runtime 的真实报错经 `classifyPluginRuntimeError()` 转成诊断卡；
3. 迁移确认弹窗（列出 `migrationsFor()` 的结果 + 差异 + 回滚入口）。

这三步都要动 UI 和 bridge，属于独立一轮，不在本次提交里假装做完。

## 本地验证记录

```
$ cd /tmp/prc && dart test
00:00 +22: All tests passed!

$ python3 /tmp/verify_removed_fields.py
  runtime rejects: ['persona', 'toolFilter']
  runtime message: tool-subagent: ${field} is no longer supported; configure
    persona and tool plugins in an Agent Preset and select it with agentPreset (spawn only)
  "never started" still in the preset registry
OK: the Dart compatibility table matches the installed runtime
```

`/tmp/prc` 是一个只含本模块的纯 Dart 工程：`app/lib` 里的同一份源文件 +
同一份测试（只把 `package:dsh_app` / `flutter_test` 换成本地包名和
`package:test`）。这样在没有 Flutter SDK 的 arm64 机器上也能跑真测试。