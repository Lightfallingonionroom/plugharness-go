# OPTIMIZE NOTES — 基于社区 1.1.71 的移植优化

## 基线（重要）

本工作区**不是**上游原版 1.1.71，而是 `realMisakaMikoto/dsh-purge` 的 `v1.1.71` tag
（`3a51be0` / tree `c97a3d4`），即社区兼容构建的起点：

- 版本号 `1.1.71`，`dshTarget: 0.2.1-rc.1`，Node `>=18`；
- 已自带社区的三处 rc.2 修复（#40 COMPLETE_PROMPT_KEEP_INJECT 的 rc.2 形状 +
  末位兜底 pattern、`HOST_SYNC` 补 `closeSync`/`readSync` 等、红队 preset 删
  `toolFilter`），以及 `scripts/check-40-and-hostfs.mjs`（18 项回归）；
- `lib/redteam/index.js` 与 `mmparko` 的 `v1.1.71`（上游原版 `5e75726`）**逐字节相同**，
  `lib/uninstall.js` 结构也一致 —— 所以镜像存档里未合并的 PR 可以近乎原样移植。

上游原版 1.1.71 = `mmparko/dsh-purge` 的 `v1.1.71`（`5e75726` / `dshTarget 0.2.0-rc.2`），
两者不是同一个 git 对象，不要混用。

## 本次移植内容

来源：`mmparko/dsh-purge` 镜像的 `archive/pr-110-head`（上游 YuJunZhiXue/dsh-purge PR #110，
commit `519280b`，作者 Minervaowl7，Refs #108）。上游删库时该 PR 仍 open；本 1.1.71 基线
没有任何一条被回灌过，所以两半都能完整移植：

### A. 卸载清理（`lib/uninstall.js`）

| 问题 | 修法 |
| --- | --- |
| `pkgMentionsPurge()` 只查 `dependencies`/`devDependencies`，而 `stripPluginFromPackage()` 已查四个依赖键 → 只写在 `optional`/`peer` 里的安装不会被列进清理名单（半卸载） | 抽 `PKG_DEPENDENCY_KEYS` 常量，两处共用；`listInstalledProfiles()` 的 `spec` 也从四个键取 |
| 现行 profile 清单把 `bundles`/`plugins` 放在 `pkg.dsh.profile` 下，旧代码只清顶层 → 卸载后留下悬空 bundle id | `profileListHolders()` + `isPurgeEntry()`，顶层与嵌套形状一起清、一起判 |

### B. 停用红队模式后宿主默认预设悬空（`lib/redteam/index.js`）

宿主取默认预设是 `agent-preset-registry.selectedDefault ?? default`，`resolve()` 解析不到
会硬抛 `agent-preset/not-found`。`undeclare()` 让 `redteam` 从注册表消失，若
`selectedDefault` 仍指着它，用户会在每个工作区都建不出新会话，而设置页已无入口可点回来。

新增导出 `releaseOwnDefault({ registry, settings, onStatus, onLog })`：只在当前默认确实是
`redteam` 时用 `settings.update('agent-preset-registry', { selectedDefault: <config.default> })`
交还；settings 不可用 / fallback 为空或自指时只落 `preset-declare.json` 状态；update 失败
被吞掉并记 `release-default-failed`，不阻塞停用。在 `ctx.effect` 的清理函数里 `void` 调用
（不 await），排在 `undeclare()` 之后。抽成独立导出是为了能用内存夹具回归，不依赖真实宿主。

> PR 原说明的边界仍适用：**已存在且记录为 `agentPreset=redteam` 的会话不受本补丁保护**，
> 宿主 `dsh-api-session-controller` 的 `composeAgent()` 对记录值显式 `resolve()`，需宿主侧回退。

### 没搬的东西

- **PR #115**（`archive/pr-115-head` / `c8ef910`，cwd 变量未注册降级）：本基线的
  `lib/identity.js` 已把 `CWD_ONLY_SUFFIX` 置空、`cordis.patch.yml` 的 `personaSuffix`
  置空，属于另一种解法；整份 cherry-pick 会冲突。
- **上游 1.1.72–1.1.90 的任何代码**（#92/#93 桌面退出追踪、rc.5 变体、事务式更新、
  evidence ledger、anchor/subagent-control、85 补丁矩阵…）：按本次要求**只保留 1.1.71**，
  一律不引入。
- `lib/net-scope.js` 及地区/行业/自有服务器门禁：保持本基线现状（未改动）。

### 回归

- `scripts/check-pr110-ports.mjs`（15 项）：四个依赖键的提及/spec/strip 对齐与幂等、
  `dsh.profile.bundles/plugins` 判定与清理、无关 profile 不误列、默认预设交还的 5 种分支、
  dispose 静态契约。只用内存夹具和临时目录，不碰真实安装目录。
- 新增 `scripts/run-checks.mjs` 汇总入口（本基线原本没有），挂到 `npm test`；
  先跑 1.1.71 自带的 `check-40-and-hostfs.mjs`（18 项），再跑新增 15 项。
- 实测：`npm test` → **34 条 PASS / 0 FAIL，exit 0**；全部 `lib/**/*.js|mjs`
  `node --check` 0 失败。

## 署名与许可

上游 YuJunZhiXue（原作者，MIT，见仓库根 `LICENSE` 与 README「署名要求」「非盈利」条款）
→ mmparko 全量镜像（PR #110 存档来源）→ realMisakaMikoto 社区 1.1.71（本工作区基线）。
本次移植未改动任何 LICENSE 文件，沿用上游署名与非盈利要求。
