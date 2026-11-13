# dsh-purge-go 融合说明

`plugins/dsh-purge-go/` 是把 dsh-purge 的破甲能力搬进 dsh-go（Android + proot）的融合插件。

## 来源与改动

- 内核：`realMisakaMikoto/dsh-purge` v1.2.3。
- 优化：`purge-research/dsh-purge-optimize` 移入的 PR #110 两半
  （卸载清理四个依赖键；停用红队后交还宿主默认预设）。
- 原生层：`NANA7MI0/dsh-purge-go` 的 dsh-go 胶囊设计。

具体改动见 `plugins/dsh-purge-go/GO-NOTES.md`。这里只记录集成与验证。

## 安装

```sh
tooling/install-purge-go.sh
```

脚本移除旧的 `dsh-purge`（若装过），把 `plugins/dsh-purge-go` 装进 `web` profile。包名保持 `dsh-purge`、版本 `1.2.3-go.1`，实现原地升级。
装完重启引擎，点输入框上方的「破甲应用」，或执行 `/purge apply`。

## 补丁层

优化版 `lib/core.js` 的 `ALL_PATCHES` 共 85 条。本融合版使用优化版自带的
`core.js` 执行器，不换成 dsh-purge-go 的 87 条 kingcharleslzy-ai 表，避免
包名别名与 surface 过滤漂移。

实测把 85 条表喂给 dsh-purge-go 的 `patches/lib/core.mjs` probe：

```
tally: {"applied":49,"no_needle":3,"no_file":1,"no_pkg":27,"partial":1,"miss":4}
```

`no_pkg` 是桌面 / 良神 / 旧版本专属包，Android proot 上不存在；`applied`
是当前引擎已被旧 dsh-purge 打过同源补丁的结果。生产路径仍走优化版 `core.js`。

## 兼容性

- DSH `0.2.2-rc.1`，Node `>=22.13.0`（运行时 24.22.1）。
- Android proot 无 Seatbelt/Landlock：沙箱补丁只改提示面；审批补丁是实际
  生效的那道闸。
- 插件内的桌面路径（`desktop.js` / `extract-asar.js` / `official-update*`）
  Android 上走不到，不报错。

## 市场

App 插件市场只收 npm 精确版本，本副本不发布到 npm，走仓库路径安装。
如需上架，需要另行发版并跑市场检查（`market/` 的规则见 `market/README.md`）。

## 许可

上游 LICENSE / NOTICE 已随插件保留：

- `plugins/dsh-purge-go/LICENSE`
- `plugins/dsh-purge-go/NOTICE`
- `plugins/dsh-purge-go/docs/upstream-dsh-purge-LICENSE`

## 验证记录（2026-11-13）

- `npm test`（插件自带回归）：全部 PASS；包含补丁 #40/hostfs、更新事务、桌面激活、
  evidence/rewind、社区更新、PR #110 卸载与默认预设交还等分组。
- dsh-go 原生插件检查器：`原生界面能显示（胶囊 2）`、`已加载宿主半侧：2 项可用；
  注册了工具：purge_status、purge_apply、purge_revert`。
- 临时 profile 安装：`dsh plugin --profile web remove dsh-purge` → `add plugins/dsh-purge-go`
  成功；profile 依赖显示 `dsh-purge 1.2.3-go.1 <- .../plugins/dsh-purge-go`。
- `dsh --profile web --dump-config`：bundle patch 解析成功，`dsh-purge` 与
  `dsh-purge/redteam*` 条目存在；旧 redteam 独立包的 “entry not found” 提示是预期的
  （那些包没装）。
- 临时引擎启动：`dsh --profile web --no-open --port 3099` 成功打印
  `dsh web: http://127.0.0.1:3099/?token=…`，无插件加载错误。
