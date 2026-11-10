#!/usr/bin/env bash
# 本机能做的检查，全跑一遍；做不了的，明确说出来而不是假装通过。
#
# 为什么需要它：这台机器是 arm64 Linux，Flutter 官方不发 arm64 版（release
# 清单里只有 x64），qemu/binfmt 也没有，所以 `flutter analyze` / `flutter test`
# / `flutter build apk` 在本机**做不到**。但仓库里有一大块东西是纯 Dart 或纯
# Node 的，在本机跑是秒级的：
#
#   dart analyze  packages/dsh_client        2 秒
#   dart analyze  packages/dsh_remote        2 秒
#   node --test   runtime/tests/*            几十秒（需要一份真实 DSH）
#
# 把这几项在本地先跑掉，就不用为了一个拼写错误去等 14 分钟的 CI。
#
# 用法：
#   tooling/local-fast-check.sh              # 跑全部能跑的
#   tooling/local-fast-check.sh --dart       # 只跑 Dart 包
#   tooling/local-fast-check.sh --node       # 只跑 runtime 测试
#   tooling/local-fast-check.sh --quiet      # 只在失败时输出
#
# 环境变量：
#   DART   dart 可执行文件（默认在 PATH 里找）
#   DSH_PREFIX  真实 DSH 安装前缀，用于 node 测试（不给就跳过 node 部分）
#
# 退出码：0 全过；1 有失败；2 环境不全（不算失败，但要说清楚）

set -u

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
ROOT=$(pwd)

QUIET=0
RUN_DART=1
RUN_NODE=1
for arg in "$@"; do
  case "$arg" in
    --dart) RUN_NODE=0 ;;
    --node) RUN_DART=0 ;;
    --quiet) QUIET=1 ;;
    -h|--help)
      # Print the header comment block verbatim, minus the leading "# ".
      sed -n '2,/^set -u$/p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^set -u$/d'
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

FAILED=0
SKIPPED=()
PASSED=()

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
hr() { [ "$QUIET" -eq 1 ] || printf '%s\n' '----------------------------------------'; }

# ---------------------------------------------------------------- Flutter 状态
# 先说清楚本机能不能做 Flutter 的活，避免有人以为这个脚本「检查过了」。
flutter_state() {
  local flutter_bin
  flutter_bin=$(command -v flutter 2>/dev/null || true)
  if [ -z "$flutter_bin" ]; then
    echo "absent"
    return
  fi
  # A binary that exists but cannot run (an x64 build on arm64) is worse than
  # none: it looks installed. Try it.
  if "$flutter_bin" --version >/dev/null 2>&1; then
    echo "usable"
  else
    echo "broken"
  fi
}

# ---------------------------------------------------------------------- Dart
find_dart() {
  if [ -n "${DART:-}" ] && [ -x "$DART" ]; then
    echo "$DART"
    return
  fi
  if command -v dart >/dev/null 2>&1; then
    command -v dart
    return
  fi
  for candidate in /root/dart-sdk/bin/dart "$HOME/dart-sdk/bin/dart"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  echo ""
}

check_dart_packages() {
  local dart
  dart=$(find_dart)
  if [ -z "$dart" ]; then
    SKIPPED+=("dart packages: no dart SDK on this machine")
    return
  fi
  say "dart: $("$dart" --version 2>&1 | head -1)"
  for pkg in packages/dsh_client packages/dsh_remote; do
    [ -d "$pkg" ] || continue
    local name
    name=$(basename "$pkg")
    say "  $name …"
    if ! ( cd "$pkg" && "$dart" pub get >/tmp/lfc-$name.log 2>&1 ); then
      say "  ✗ $name pub get"
      tail -20 /tmp/lfc-$name.log
      FAILED=1
      continue
    fi
    if ! ( cd "$pkg" && "$dart" analyze >>/tmp/lfc-$name.log 2>&1 ); then
      say "  ✗ $name analyze"
      tail -30 /tmp/lfc-$name.log
      FAILED=1
      continue
    fi
    PASSED+=("$name analyze")
    say "  ✓ $name analyze"
  done
}

# ---------------------------------------------------------------------- Node
check_runtime_tests() {
  if ! command -v node >/dev/null 2>&1; then
    SKIPPED+=("runtime tests: no node on this machine")
    return
  fi
  if [ -z "${DSH_PREFIX:-}" ]; then
    SKIPPED+=("runtime tests: DSH_PREFIX not set (needs a real DSH install)")
    return
  fi
  if [ ! -d "$DSH_PREFIX" ]; then
    SKIPPED+=("runtime tests: DSH_PREFIX=$DSH_PREFIX does not exist")
    return
  fi
  if [ ! -d runtime/tests ]; then
    SKIPPED+=("runtime tests: runtime/tests is missing")
    return
  fi
  say "node: $(node --version)  DSH_PREFIX=$DSH_PREFIX"
  # 只跑不依赖 bridge/engine、也不依赖完整 DSH 包集的那几个。runtime/tests
  # 有 159 个文件，全跑要几十分钟并且大部分需要一台活着的 host——那是 CI 的活。
  #
  # plugin-bundle-membership / plugin-config-bundles 需要
  # @deepseek-ai/dsh-official-bundles，一份裁剪过的 DSH 副本没有它，所以放在
  # 白名单外：它们跑不起来时报的是「环境不全」，不是「代码坏了」。
  local allowed=(
    cordis-lifecycle.test.mjs
    boot-cache.test.mjs
  )
  local files=()
  for name in "${allowed[@]}"; do
    if [ -f "runtime/tests/$name" ]; then
      files+=("runtime/tests/$name")
    fi
  done
  if [ "${#files[@]}" -eq 0 ]; then
    SKIPPED+=("runtime tests: none of the offline suites are present")
    return
  fi
  say "  running ${#files[@]} offline suites …"
  if DSH_PREFIX="$DSH_PREFIX" node --test "${files[@]}" >/tmp/lfc-node.log 2>&1; then
    PASSED+=("runtime offline tests")
    say "  ✓ runtime offline tests"
  else
    say "  ✗ runtime offline tests"
    grep -E '^# (pass|fail)|^not ok' /tmp/lfc-node.log | head -30
    FAILED=1
  fi
}

# --------------------------------------------------------------------- main
say "local fast check — $(date '+%Y-%m-%d %H:%M:%S %Z')"
say "repo: $ROOT @ $(git rev-parse --short HEAD 2>/dev/null || echo '?')"
hr

case "$(flutter_state)" in
  absent)
    say "flutter: 本机没有 Flutter SDK → analyze / test / build APK 都做不了，交 CI"
    ;;
  broken)
    say "flutter: 装了但跑不起来（这是 arm64 机器上的 x64 版）→ 交 CI"
    ;;
  usable)
    say "flutter: 可用 → 顺手跑 analyze"
    if ( cd app && flutter analyze --no-pub >/tmp/lfc-flutter.log 2>&1 ); then
      PASSED+=("flutter analyze")
      say "  ✓ flutter analyze"
    else
      say "  ✗ flutter analyze"
      tail -30 /tmp/lfc-flutter.log
      FAILED=1
    fi
    ;;
esac
hr

[ "$RUN_DART" -eq 1 ] && check_dart_packages
[ "$RUN_NODE" -eq 1 ] && check_runtime_tests

hr
if [ "${#PASSED[@]}" -gt 0 ]; then
  say "passed:"
  for p in "${PASSED[@]}"; do say "  ✓ $p"; done
fi
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  say "skipped (不是通过，是没做):"
  for s in "${SKIPPED[@]}"; do say "  – $s"; done
fi

if [ "$FAILED" -ne 0 ]; then
  say ""
  say "有失败。修完再推，别把 14 分钟的 CI 花在拼写错误上。"
  exit 1
fi
say ""
say "本机能查的都过了。Flutter 侧（analyze / test / APK）仍然要 CI。"
exit 0