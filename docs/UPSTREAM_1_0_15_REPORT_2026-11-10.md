# 上游 v1.0.15 差异报告（2026-11-10）

> 分析对象：`v1.0.14` → `v1.0.15`（`upstream/main` @ `8f31b2ed`）
> 我们当前基点：`d1f45d29`（main）
> 方法：`git diff` / `git merge-tree` 只读探测，**未做任何合并**

---

## 一、结论摘要

| 项 | 结果 |
|---|---|
| 提交数 | 24（其中非 merge 19） |
| 文件变化 | 78 |
| **试合并冲突** | ✅ **0 个** |
| 碰我们的魔改 UI 文件？ | ❌ **没有** |
| 碰运行时 patch 链？ | ⚠️ 上游新增 2 个 patch + pins 追加 |

**风险评级：低。** 比 v1.0.13/14 那次（56 个冲突）简单一个数量级。

---

## 二、上游改了什么

### 2.1 运行时补丁（14 个补丁，编号 2610–2621）

这是本版的**主要内容**：

| 编号 | 内容 |
|---|---|
| 2610 | 运行日志尾部只收当前这次启动的输出 |
| 2612 | 运行状态的采样和入队保持同一顺序 |
| 2613 | C2 在第一次 invoke 之前装上受控时钟（测试） |
| 2614 | 审批提交中重发通知，保留第一次的决定 |
| 2616 | 视频音频焦点回调只作用于申请它的那次播放 |
| 2617 | 永久删除会话时一并删掉迁移暂存的正文 |
| 2618 | 最近会话快捷方式迁移成功后才关闭旧桌面入口 |
| 2619 | 持久终端就绪计时改用单调时间 |
| 2620 | Agent Team 冷恢复时未消费的初始输入不判失败 |
| 2621 | 普通停止后，后台线程迟到的刷新不再发前台通知 |
| — | 升级日志持久化与恢复检查加固 |
| — | **升级时保留已安装系统**（重要） |

### 2.2 新增功能

| 项 | 说明 |
|---|---|
| **用量统计报机型和系统版本** | contract v2，`UsagePlugin.kt` + `UsageDeviceTest.kt` |
| **ML Kit 配对前初始化** | 修复 #802，`MlKitInitialization.kt` / `MlKitRuntime.kt` |
| **ColorOS 免打扰自检** | `fix/coloros-gate-817` |

### 2.3 原生 Kotlin 改动

- `DshService.kt` — 通知更新改到主线程 Handler（`Looper.getMainLooper()`）
- `MainActivity.kt` / `LauncherIconPlugin.kt` / `MediaVideoPlugin.kt` / `ChatNotifier.kt` / `MlKitSession.kt`
- `EngineUpgrade.kt` / `RuntimeInstaller.kt` / `RuntimeUpgradeCompatibility.kt` / `RuntimeController.kt`
- `AndroidManifest.xml` / `build.gradle.kts`

### 2.4 文档与技能

- `docs/` 9 个文件
- `app/assets/skills/dsh-go-guide/` 中英 4 个文件

---

## 三、与我们魔改的冲突分析

### ✅ 零冲突的文件（最重要的部分）

**上游完全没碰我们改过的这些**：

```
app/lib/ui/theme/*                      ← 十色色板（本轮修复的）
app/lib/ui/chat/empty_state.dart        ← 空态品牌化
app/lib/ui/chat/empty_actions.dart      ← 建议卡
app/lib/ui/shell/sessions_drawer.dart   ← Agent 体征条
app/lib/ui/settings/appearance/*       ← 页面内平铺色板
app/lib/ui/settings/app_menu.dart
```

### ⚠️ 需要留意的两处

**1. `DshService.kt`**

| 我们改的 | 上游改的 | 是否重叠 |
|---|---|---|
| `ACTION_*` 常量前缀 `ccch1mneyyy` → `lightfallingonionroom`（5 行） | 加 `Handler(Looper.getMainLooper())` + 主线程判断 | ❌ **不重叠** |

→ 可以自动合并，我们的包名前缀保留。

**2. 运行时 patch 链**

| 项 | 上游 | 我们 |
|---|---|---|
| 新增 patch | `zzzzzzzzzz-agent-team-input-recovery.diff`<br>`zzzzzzzzzz-terminal-readiness-clock.diff` | `zzzzz…(52个z)-assistant-stream-shape.diff` |
| 前缀长度 | **9 个 z** | **52 个 z** |
| 排序结果 | 排在**前面** | 排在**最后** |
| `pins.json` | +16 行（纯追加） | +8 行（纯追加） |

→ **不冲突**，且上游 patch 不会覆盖我们的。

### ❓ 待确认

`AndroidManifest.xml` 上游改了——需确认是否涉及权限（我们加了 CAMERA）。合并时检查即可。

---

## 四、合并建议

### 推荐路径

```
1. git fetch upstream --tags
2. git merge upstream/main            # 预期 0 冲突
3. 检查 AndroidManifest.xml 权限（CAMERA 是否还在）
4. 跑 flutter analyze + Android JVM
5. 跑 test_patch_dsh.py（验证 patch 哈希链）
6. 推 main，等 CI
```

### 回滚点

`backup-before-upstream-merge` = `63bad57b`（上次合并前）
本轮建议新建：合并前先 `git tag backup-before-1.0.15`

### 明确不做

- ❌ 不改 `applicationId`（保持 `io.github.lightfallingonionroom.dsh_app`）
- ❌ 不改 `android:label`（保持 "PlugHarness Go"）
- ❌ 不重拍 golden
- ❌ 不扩大 Runtime 治理范围

---

## 五、下一步

本报告**只做只读分析**，没有执行合并。

建议顺序：
1. **你先实机验证 APK**（已下载到 `/sdcard/Download/`，含十色修复）
2. 验证通过后，我再执行合并
3. 合并后跑 CI 验证，再出报告

> 上游当前最新是 `v1.0.15`（11-10），比我们基线（v1.0.14，11-09）只差一天。