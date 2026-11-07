#!/usr/bin/env bash
# Sign a CI-built APK with the project's fixed release key.
#
# Why this exists: the CI runner has no release key (it must never hold one),
# so `tooling/build-apk.sh --release` falls back to the debug key — and every
# runner mints a NEW debug key, which makes each build un-installable over the
# last one. This re-signs the artifact with the key kept outside the repo,
# so upgrades keep their data.
#
#   tooling/sign-release.sh <unsigned.apk> [out.apk]
#
# The key lives at ~/keys/dshgo-release.jks (or $DSHGO_KEYSTORE), the alias is
# dshgo, and the password is read from ~/keys/dshgo-release-password.txt
# (or $DSHGO_KEY_PASSWORD). Both are git-ignored and never belong in the repo.
set -euo pipefail

apk=${1:?usage: sign-release.sh <unsigned.apk> [out.apk]}
out=${2:-${apk%.apk}-signed.apk}

keystore=${DSHGO_KEYSTORE:-$HOME/keys/dshgo-release.jks}
pwfile=${DSHGO_KEY_PASSWORD_FILE:-$HOME/keys/dshgo-release-password.txt}
alias_name=${DSHGO_KEY_ALIAS:-dshgo}

[[ -f $apk ]] || { echo "sign-release: no such APK: $apk" >&2; exit 1; }
[[ -f $keystore ]] || { echo "sign-release: no keystore at $keystore" >&2; exit 1; }

if [[ -n ${DSHGO_KEY_PASSWORD:-} ]]; then
  pw=$DSHGO_KEY_PASSWORD
elif [[ -f $pwfile ]]; then
  pw=$(cat "$pwfile")
else
  echo "sign-release: no password (set DSHGO_KEY_PASSWORD or $pwfile)" >&2
  exit 1
fi

# Find an apksigner: PATH first, then the jar (the SDK's native binaries are
# x86-64 and will not run on an arm64 host; the jar runs anywhere java does).
signer=$(command -v apksigner || true)
if [[ -z $signer ]]; then
  for bt in "$HOME"/Android/build-tools/*/lib/apksigner.jar \
            "${ANDROID_HOME:-/nonexistent}"/build-tools/*/lib/apksigner.jar; do
    [[ -e $bt ]] && { signer=$bt; last=$bt; }
  done
  [[ -z $signer && -n ${last:-} ]] && signer=$last
fi
[[ -n $signer ]] || { echo "sign-release: no apksigner found" >&2; exit 1; }

run() {
  if [[ $signer == *.jar ]]; then
    java -jar "$signer" "$@"
  else
    "$signer" "$@"
  fi
}

# v1 too: a handful of Android 8 devices still check it, and it costs nothing.
run sign \
  --ks "$keystore" \
  --ks-key-alias "$alias_name" \
  --ks-pass "pass:$pw" \
  --key-pass "pass:$pw" \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --out "$out" \
  "$apk"

run verify --print-certs "$out" | sed -n '1,6p'
echo "sign-release: wrote $out"
