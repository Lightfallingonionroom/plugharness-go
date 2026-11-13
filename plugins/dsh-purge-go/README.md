# dsh-purge（dsh-go 融合版）

把 **dsh-purge** 的破甲能力搬进 **dsh-go**（Android + proot）的融合插件。仓库目录是 `plugins/dsh-purge-go`，但包名保持 `dsh-purge`、版本 `1.2.3-go.3`，这样可以直接替换已装的 dsh-purge，更新/卸载逻辑不受影响。

- **内核**：`realMisakaMikoto/dsh-purge` v1.2.3，并含 `purge-research/dsh-purge-optimize` 移入的 PR #110 修复
  （卸载清理四个依赖键、停用红队后交还宿主默认预设）。
- **原生层**：移植 `NANA7MI0/dsh-purge-go` 的 dsh-go 胶囊，输入框上方出现「破甲状态 / 破甲应用」。
- **补丁层**：85 条引擎补丁（优化版自带），覆盖审批、沙箱、身份段、工具提示面；手机 proot 上不依赖 Seatbelt，
  实际生效的是「审批 fail-open + 提示面中性化」。
- **目标**：DSH `0.2.2-rc.1`，Node `>=22.13.0`，Android proot 环境。

## 安装

在 App 的终端或本机环境里执行：

```sh
tooling/install-purge-go.sh
```

脚本会：

1. 从 `web` profile 移除旧的 `dsh-purge`（如果装过）；
2. 把 `plugins/dsh-purge-go` 装进 `web` profile（包名仍是 `dsh-purge`，版本 `1.2.3-go.3`，原地升级）；
3. 提示重启引擎。

也可以手动装：

```sh
dsh plugin --profile web add /path/to/plugharness-go/plugins/dsh-purge-go
```

## 使用

- 输入框上方点 **破甲状态**：插入一段提示词，让模型调 `purge_status` 报两层状态。
- 输入框上方点 **破甲应用**：直接执行 `/purge apply`，把 85 条补丁打到引擎包。
- 对话里输入 `/purge` 看全部命令（status / on / off / apply / revert / prompt / variant / cat 等）。
- 工具：`purge_status`、`purge_apply`、`purge_revert`。

**补丁层默认不自动应用**（`autoApplyOnStart: false`）。装完请手动点一次「破甲应用」，或执行 `/purge apply`。

## 与上游的差异

| 项 | dsh-purge-go | 本融合版 |
| --- | --- | --- |
| 内核 | 自带轻量注入层 + 87 条 kingcharleslzy-ai 补丁 | dsh-purge 1.2.3 + PR #110 优化，85 条补丁 |
| 原生 UI | 破甲状态胶囊 | 破甲状态 + 破甲应用胶囊 |
| 红队 | 不含（另装） | 含 redteam 工具/预设/技能（随内核） |
| 桌面代码 | 已剥离 | 保留但 Android 上走不到；如需纯净可再裁 |

## 许可与署名

- 上游 `YuJunZhiXue/dsh-purge`（MIT）→ `realMisakaMikoto/dsh-purge` v1.2.3（MIT，含 Apache-2.0 选入部分）。
- `NANA7MI0/dsh-purge-go`（AGPL-3.0）的原生胶囊设计。
- 完整许可证与 NOTICE 见 `LICENSE`、`NOTICE`、`docs/upstream-dsh-purge-LICENSE`。
- 上游 README 见 `README-upstream.md` / `README-upstream.zh-CN.md`。

## 技术说明

见 `GO-NOTES.md`。
