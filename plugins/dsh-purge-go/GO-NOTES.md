# GO-NOTES — dsh-go 融合记录

## 来源

- `realMisakaMikoto/dsh-purge` v1.2.3：内核（`lib/core.js`、`lib/identity.js`、`lib/redteam/*`、`presets/redteam`、`skills/redteam`）。
- `purge-research/dsh-purge-optimize`：在 v1.2.3 之上移入 PR #110 两半：
  - `lib/uninstall.js`：四个依赖键（`dependencies` / `devDependencies` / `optionalDependencies` / `peerDependencies`）
    的提及、spec、strip 对齐；`pkg.dsh.profile.bundles/plugins` 嵌套形状清理。
  - `lib/redteam/index.js`：`releaseOwnDefault()`，停用红队时把 `agent-preset-registry.selectedDefault`
    交还给 `config.default`，避免注册表悬空。
- `NANA7MI0/dsh-purge-go`：dsh-go 原生胶囊层（`package.json.dshGo.contributes.composer.actions`）。

## 改动

1. `package.json`
   - `name` 保持 `dsh-purge`（目录是 `plugins/dsh-purge-go`），`version` → `1.2.3-go.1`。
     这样可以直接替换已装的 dsh-purge；更新、卸载、profile 依赖逻辑里的 `dsh-purge` 硬编码不需要改。
   - 增加 `dshGo.manifest`：`purge-status`（插入状态提示词）与 `purge-apply`（执行 `/purge apply`）。
   - 移除 `dsh.install` 远程 tarball 指向（本副本从仓库路径安装）。
2. `cordis.patch.yml`
   - 条目 id / name 保持 `dsh-purge` / `dsh-purge/redteam*`（包名未变）。
   - 插件内部仍以 `dsh-purge` 作为系统提示段名与状态目录，兼容已有状态与补丁 marker。
3. 文档：新增 `README.md`、`GO-NOTES.md`；上游 README 改名为 `README-upstream*`。

## 补丁表

优化版 `lib/core.js` 的 `ALL_PATCHES` 共 85 条，与 `dsh-purge-go` 的 87 条 kingcharleslzy-ai 表不是同一套。
本融合版使用优化版自带的 `core.js` 执行器，避免格式/别名漂移；`dsh-purge-go` 的 `patches/patches.json`
未并入。实测把 85 条表喂给 dsh-purge-go 执行器 probe 可识别（49 applied / 27 no_pkg / 4 miss / 3 no_needle /
1 no_file / 1 partial），但生产路径仍走优化版自己的 `core.js`。

## 兼容性

- DSH `0.2.2-rc.1`（`dshTarget`），Node `>=22.13.0`（运行时 24.22.1）。
- Android proot：无 Seatbelt/Landlock，沙箱补丁只改提示面；审批补丁是实际生效的那道闸。
- 插件内含桌面路径（`desktop.js` / `extract-asar.js` / `official-update*`），Android 上走不到，不报错。

## 已知边界

- 补丁层默认 `autoApplyOnStart: false`，装完需手动 `/purge apply`。
- 优化版 PR #110 的「已存在且记录为 `agentPreset=redteam` 的会话」仍由宿主 `composeAgent()` 显式 `resolve()`，
  本补丁不保护这类历史会话。
- 未在 App 插件市场发布；市场只收 npm 精确版本，本副本走仓库路径安装。

## 2026-11-13 补充修复

1. **宿主探测**：`findAiBaseWeb()` 现在优先返回 `/opt/dsh/node_modules/@deepseek-ai`，
   并支持 `DSH_AI_ROOT` 覆盖；同时过滤 `/root/workspace/`、`/workspace/`、`/ai agent/`
   下的副本。修复「补丁打到工作区源码副本、真实引擎没被清洗」的问题。
2. **bundle patch**：删掉非 insert 的 `- id: dsh-purge` 覆盖行，只保留 `insert`，
   避免宿主报 `entry "dsh-purge" not found` / 重复入队（与 Evans-repo- 的兼容修法一致）。
3. **原生工具卡**：新增 `lib/dsh-go-card.js`，把 `purge_status` / `purge_apply` /
   `purge_revert` 的输出挂成 dsh-go 文本卡；胶囊仍是「破甲状态 / 破甲应用」。
4. **验证**：`findAiBase()` 实测返回 `/opt/dsh/node_modules/@deepseek-ai`；
   `npm test` 全绿；dsh-go 检查器显示胶囊 2 个、工具 3 个。
