#!/usr/bin/env bash
# 在已收进仓库的 purge 版本之间切换。
#
#   tooling/switch-purge.sh go [profile]      融合版（默认）
#   tooling/switch-purge.sh evans [profile]   Evans-repo- 1.1.71-rc2.1（面向 0.2.1-rc.2）
#   tooling/switch-purge.sh real [profile]    realMisakaMikoto 1.2.3
#
# 切换会替换 profile 里的 dsh-purge；装完重启引擎。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROFILE="${2:-web}"

case "${1:-go}" in
  go)    PLUGIN="$ROOT/plugins/dsh-purge-go" ;;
  evans) PLUGIN="$ROOT/plugins/dsh-purge-evans" ;;
  real)  PLUGIN="$ROOT/plugins/dsh-purge-real" ;;
  *) echo "用法: $0 [go|evans|real] [profile]" >&2; exit 1 ;;
esac

command -v dsh >/dev/null 2>&1 || { echo "找不到 dsh 命令" >&2; exit 1; }
[ -f "$PLUGIN/package.json" ] || { echo "找不到插件：$PLUGIN" >&2; exit 1; }

dsh plugin --profile "$PROFILE" remove dsh-purge >/dev/null 2>&1 || true
dsh plugin --profile "$PROFILE" add "$PLUGIN"

echo "已安装 $PLUGIN 到 profile「$PROFILE」。"
echo "重启引擎后生效。"
