# PlugHarness-Go All-in Flash 遇阻救急手册

> 日期：2026-11-12
> 配套任务书：`docs/ALL_IN_FLASH_TASKBOOK_2026-11-12.md`
> 适用对象：Flash 执行窗口和旗舰模型复核
>
> 核心原则：先分类、再保留现场、再做最小可逆动作。任何不确定的副作用都按“未确认”处理，不把失败伪装成成功。

## 0. 紧急总流程

### 第 0 步：停手并记录

发生以下任一情况，立即停止当前任务，不继续堆代码：

- 真实用户数据可能被删除、覆盖、导出或写入日志。
- 远程主机/DSH Host 返回未知错误或动作结果未确认。
- Flutter analyze 出现新错误，或 l10n 生成差异不为 0。
- CI 分片失败但没有取到最小失败测试名。
- 主机协议能力与任务书假设不一致。
- Android 原生后台屏、Shizuku、ADB、MediaProjection、安装器出现状态不确定。
- 磁盘余量接近项目红线 11 GiB，或 rootfs/node_modules/Gradle 缓存可能超预算。

记录：

```text
task: AI-xx
HEAD:
branch:
working tree summary:
first failing command:
first error line:
files modified by this task:
user data touched: yes/no/unknown
remote/device side effect: yes/no/unknown
```

### 第 1 步：保护工作树和用户数据

- 不运行 `git reset --hard`、`git checkout --`、`git clean`、`rm -rf`。
- 不把 `.backup/chats/` 纳入 `git add`、测试夹具、ZIP 或诊断包。
- 不为了清理测试环境删除 runtime/rootfs、主机 profile、对话或工作区。
- 只对本任务创建的临时目录操作；路径先 `realpath`/白名单校验。
- 若有用户未提交修改，先报告，不替用户 stash/reset。

### 第 2 步：分类

| 类别 | 典型症状 | 第一处理 |
|---|---|---|
| 语法/Analyzer | undefined、unused、类型错误 | 只修当前变更相关文件，重跑 analyzer |
| 生成/l10n | `gen diff`、ARB key 缺失 | 改 parts ARB，按生成流程重跑，不手改 gen |
| Widget 行为 | Finder 0、状态没变 | 先判入口路径/状态链，不能直接放宽断言 |
| Golden | pixel diff、文件不存在 | 区分必然视觉变更和真实布局错误，先不重拍全量 |
| CI 并发 | 新 push 取消旧 CI | 停推送，等待当前 run 或使用最终 SHA 重新跑 |
| Host 协议 | 404/409/unsupported/unconfirmed | 读取 host 能力和 raw response，不能本地猜成功 |
| Android 原生 | PlatformException、通道未注册 | 先取 status/版本/日志，检查 ABI 和 native 注册 |
| 后台屏/任务 | slot busy、cleanup pending、资源未确认 | 禁止强制释放，执行官方 cleanup/recovery 流程 |
| Remote | 指纹/连接/权限/路径错误 | 保留 host identity，不能回退到另一个 host |
| 备份恢复 | manifest/hash/schema/restore failure | 保留原数据和 restore point，进入预览/回滚流程 |
| 磁盘 | No space、APK/rootfs 过大 | 只统计，不盲删；先确认可清理缓存范围 |

## 1. Flutter / Dart / l10n

### 1.1 Analyzer 新错误

1. 记录完整错误文件、行号、首次出现 SHA。
2. 与 `git diff` 对照，确认是本任务引入还是基线既存。
3. 只做最小修复；不要用 `// ignore` 隐藏错误，除非已有同类契约并写明理由。
4. `dart format` 只对明确变更文件运行；禁止全仓格式化。
5. 修完执行：

```bash
python3 app/tool/l10n_merge.py --check
python3 app/tool/guide_sync.py --check
```

### 1.2 l10n 生成差异

正确路径：

```text
修改 app/lib/l10n/parts/*.arb
中英文同步
运行 python3 app/tool/l10n_merge.py
运行 python3 app/tool/l10n_merge.py --check
让 CI 的 Flutter 生成步骤验证
```

禁止：手改 `app/lib/l10n/gen/*.dart` 后只提交生成物；禁止删 key 让测试绿；禁止把中文直接塞进 Dart UI。

### 1.3 Provider/状态测试失败

先问三个问题：

- 测试是否在等异步加载但只 pump 了一帧？
- Finder 是否仍指向已删除的旧 UI 入口？
- 状态是否来自正确的 host/session/account scope？

允许调整测试前置等待或导航入口；不允许删除真实行为断言、把 `findsOneWidget` 改成 `findsNothing` 来掩盖缺失功能。

## 2. CI / Flutter 分片 / Golden

### 2.1 CI 失败处理

1. 不要马上 push 新提交，因为仓库并发策略可能取消当前 run。
2. 用 GitHub API 取当前 SHA 的 jobs，先看失败 step。
3. 只下载失败 job 日志，按 `warning/error/Expected/Actual/Pixel test failed/Test failed` 提取摘要。
4. 记录测试总数和失败文件；不要把大日志全文回显到工具通道。
5. 只有确认当前 run 结束后，才 push 修复提交。

### 2.2 Golden 分类

- **预期差异**：字体、配色、明确布局契约改动导致像素差异；保留失败证据，所有行为测试先绿，再统一重拍。
- **真实差异**：按钮越界、文字裁剪、标题消失、键盘/安全区错位、深浅模式不一致；修代码，不重拍掩盖。
- **基线文件不存在**：先确认测试名称和 `--update-goldens` 输出路径，不要复制任意 PNG。

重拍前必须满足：analyze 绿、行为测试绿、目标尺寸/主题/字体环境稳定、用户已确认该批视觉方向。重拍后记录新旧 golden 的测试集合和 SHA。

### 2.3 CI 取消

- 旧 run 被新 push 取消，不等于失败。
- 新 run 的 SHA 必须与待验收代码一致。
- APK 构建必须检查 workflow head SHA、artifact run id、包名、版本、ABI 和签名；不能只看“artifact 存在”。

## 3. Host / DSH / 远程协议

### 3.1 权限直切失败

用户已选择“不做二次确认”，但这不等于忽略 Host 回执：

1. 菜单立即进入 `applying`，禁止显示已成功。
2. 调用现有 `setPermissionPreset`/对应 host API。
3. 等回执和 permission state refresh。
4. 成功显示真实 preset；失败恢复原选中项并显示稳定错误码/错误文案。
5. 断线、旧 Host、read-only、safe mode 都是独立状态。
6. 新对话 disabled，不调用创建 session。

### 3.2 模型/provider 配置失败

- 404 不等于自动追加 `/v1` 永久写入；只能沿现有 discover 兼容策略尝试，并显示最终使用地址。
- 401/403 不自动轮换 Key，除非明确实现并记录 Key pool 策略。
- 429、5xx、DNS、TLS、模型列表空返回分别分类。
- provider profile 写入成功、credential 写入失败时，显示部分成功和恢复操作，不回滚成假状态。
- 保存后必须重新读取 host profile，确认实际值，不以本地 draft 为准。

### 3.3 思考档位失败

- `model.efforts` 为空：不显示可选档位；若原选择已失效，显示“当前模型不支持/目录未加载”，不静默换档。
- Host 返回 `UNSUPPORTED_REASONING_EFFORT`：保留用户原值/回读结果，记录不支持原因。
- endpoint 规则与当前 provider 不匹配：不执行 JSON action。
- 迟到的模型目录/host response 必须带 generation/identity，不能覆盖用户刚切换的模型。

### 3.4 Remote host 能力不一致

所有 remote capability 先查 supports/version：

- 不支持 workspace export/import：显示不支持，不改用宽泛 `workspaceFiles` 读数据库。
- 不支持 terminal/files/team：按钮 disabled 或明确 unavailable。
- 指纹改变：停止连接，不自动信任新指纹。
- 断线后结果未确认：保留 `result_unconfirmed`，不得自动重发有副作用的请求。

## 4. Android / 后台屏 / Shizuku / 任务

### 4.1 通道未注册或设备能力不符

检查顺序：

```text
Android SDK / ABI / target version
MethodChannel 名称和 native plugin 注册
当前 APK 是否含 arm64 native 产物
runtime phase
PhoneStatus / background status
Shizuku/Sui/ADB/root provider 和授权
Android 14+ VirtualDisplay 能力
```

`MissingPluginException` 只能归类为当前构建没有该 native module 或通道未注册，不能当成用户授权失败。

### 4.2 后台屏资源占用

- `cleanup_pending` 时禁止开新任务、禁止手工强制释放资源。
- 先调用现有 `retryBackgroundGateCleanup`/恢复流程，记录 handle、taskId、generation。
- 任务取消不等于已经发送的 tap/type 被撤销；UI 必须提示。
- 任务 owner 失效、host 切换、App 被杀后，迟到 cleanup 不得释放新任务的 slot。
- capacity 只读原生 effectiveLimit；不能仅在 Flutter 把上限改大。
- Android 12/13 与 14+ 行为分开测试；后台屏需要用户授权和 ROM 支持。

### 4.3 并发死锁

当多个任务等待相同 App/resource：

1. 显示等待对象和等待时长。
2. 检测 A 等 B、B 等 A，不无限重试。
3. 提供安全停止/接管路径。
4. 不绕过原生 admission 或直接新建第二个 VirtualDisplay。
5. 记录可重放的状态夹具，修复前不在真机上反复产生真实副作用。

## 5. 备份 / 恢复事故

### 5.1 备份创建失败

- 保留上一次成功备份。
- 临时文件不进入正式 manifest。
- 校验失败直接删除临时文件，报告原因；不要标记“备份成功”。
- 空间不足只清理本任务生成的临时文件；缓存清理需用户明确授权/既有清理接口。
- key/cookie/token 不得因调试日志进入备份。

### 5.2 恢复包损坏/版本不兼容

恢复前必须按顺序：

```text
magic / schema version
manifest JSON
size limits
path normalization / traversal
SHA-256
sensitive fields policy
source host/account compatibility
```

不通过时只显示预览错误，不触碰当前数据。

### 5.3 恢复中断

- 按 journal 查到最后确认步骤。
- 原始数据和 restore point 不能删除。
- 能回滚就回滚并验证；不能确认就显示 `restore_unconfirmed`，禁止第二次自动恢复。
- 重启后先 reconciliation，再允许用户继续或放弃。
- 远程恢复失败不能把本地状态改成已恢复。

### 5.4 数据范围争议

如果发现“备份聊天”实际只能导出日志/回放，任务必须把名称改成“导出/回放”，不能继续叫“完整备份”。完整备份只有在能恢复原始主机状态、会话/附件范围和版本契约都明确后才可命名。

## 6. Token 用量 / 价格 / 路由

- `null` token 与 0 不同：显示未知计数。
- 估算价格必须带 `estimated`、price source、price timestamp；没有公开价格显示未计价。
- 同一 event 重试/重连不得重复入账；优先 stable event id，其次 source+sequence+session+turn 组合键。
- 价格变更不回写历史账单，历史行使用当时 price snapshot 或标明按当前价格重算。
- provider/model alias 归一不得丢 raw identity；统计页面必须能展开到原始 provider/model/route。
- route failover 必须显示切换原因和当前 route；不能静默让用户以为仍在原 provider。

## 7. 电脑 CLI / MCP / 网络暴露

- 默认关闭网络监听；USB/ADB 优先。
- Wi-Fi/VPN 入口要有显式开关、随机/高熵 token、绑定范围、撤销和状态页。
- 不把 API key、聊天密文、Shizuku token 注入电脑端。
- 电脑端确认动作回手机，不能由远程客户端伪造“用户已确认”。
- disconnect 后 outbox 需要幂等 requestId；重连后查原任务，不盲重发。
- 任务台只读历史的开关默认关闭，记录授权范围和关闭后的撤销行为。

## 8. 许可与参考代码

- Operit LGPL-3.0：只借鉴设计、协议思想和公开数据结构，禁止复制实现代码、资源或受限文案。
- OpenMinis GPL-3.0：只读功能研究，禁止移植代码。
- Mika Apache-2.0、mobile-mcp Apache-2.0、Angel Unlicense：仍需保留来源与许可证核对，不能把参考项目名字/品牌/素材做进 PlugHarness UI。
- 所有采用的外部证据写入研究/实现文档：仓库、commit、文件路径、许可、借鉴内容和未采用部分。

## 9. 磁盘与构建急救

项目磁盘红线是至少 11 GiB 可用，新增目标尽量不超过 12 GiB。

遇到 No space：

1. 停止构建/解压/备份，不重试写入。
2. 记录 `df -h`、大目录和任务阶段。
3. 只清理本任务生成的 `/tmp` 下载、CI 日志、Gradle/pub/npm 缓存中明确可再生项。
4. 不删除 runtime/rootfs、用户 `/root`、`.backup/chats/`、APK、未交付 artifacts。
5. rootfs 去重保持硬链接 + 写时复制约束，不启用 reflink 假设。
6. 构建前重新算预算：APK、runtime、node_modules、Gradle cache、测试 artifact。

## 10. 何时必须停下等待旗舰或用户

### 停下问旗舰模型

- 需要选择新的数据模型/协议，且现有主机能力不足以证明哪条路正确。
- 需要删除/迁移/覆盖已有用户数据。
- 需要决定未知费用、隐私范围、备份范围或路由失败策略。
- 需要改变现有 permission/capability 语义。
- 需要把 UI 变化解释成“产品要求”，但用户没有明确说。
- 两个功能模块都合理但会造第二条数据链路，无法在当前边界内统一。

### 停下等用户明确授权

- 安装、覆盖、卸载 APK。
- 访问、发送、外发真实凭据/聊天/截图/诊断包。
- 打开系统全局 VPN、后台悬浮、无障碍、Shizuku/root/ADB 等用户权限。
- 产生真实第三方模型请求或付费请求。
- 删除或重置 runtime、rootfs、聊天、工作区、插件或备份。

## 11. 失败报告模板

```text
AI task:
Window:
HEAD / branch:
First failing command:
First error:
Classification:
Files changed by this task:
Tests run and result:
CI run / job / SHA:
Device / Android / ABI:
User data touched:
Remote or device side effect:
Recovery attempted:
Current safe state:
Recommended next action:
```

没有填完上述字段，不得说“已修复”或“已完成”。