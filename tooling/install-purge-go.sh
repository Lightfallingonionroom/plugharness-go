#!/usr/bin/env bash
# Install the merged dsh-purge-go plugin into a DSH profile.
#
#   tooling/install-purge-go.sh [profile]     default: web
#
# Removes the old dsh-purge (if present) and installs plugins/dsh-purge-go
# from this repository. The patch layer is not auto-applied: after the
# engine restarts, tap 破甲应用 above the composer or run /purge apply.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROFILE="${1:-web}"
PLUGIN="$ROOT/plugins/dsh-purge-go"

command -v dsh >/dev/null 2>&1 || { echo "找不到 dsh 命令，请先启动本机引擎或确认 PATH" >&2; exit 1; }
[ -f "$PLUGIN/package.json" ] || { echo "找不到插件：$PLUGIN" >&2; exit 1; }

# 旧版本可能占着同一个 profile；先摘掉，失败不算错。
dsh plugin --profile "$PROFILE" remove dsh-purge >/dev/null 2>&1 || true
dsh plugin --profile "$PROFILE" remove dsh-purge-go >/dev/null 2>&1 || true

dsh plugin --profile "$PROFILE" add "$PLUGIN"

echo ""
echo "已把 dsh-purge-go 装进 profile「$PROFILE」。"
echo "下一步：重启引擎，然后点输入框上方的「破甲应用」，或执行 /purge apply。"
echo "状态：/purge status，或点「破甲状态」胶囊。"
