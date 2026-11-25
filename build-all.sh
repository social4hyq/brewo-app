#!/usr/bin/env bash
# 一键：编译 native .so -> hvigor 构建 HAP -> 注入 .so -> 签名安装
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

CLT="${BREWO_CLT:-/opt/electron-ohos-clt}"
[ -d "$CLT" ] || CLT="$HOME/HarmonyPC/Myspace/build-test/electron-ohos-clt"
SDK="${BREWO_SDK:-$CLT/sdk}"
HVIGOR="${BREWO_HVIGOR:-$CLT/hvigor/bin/hvigorw}"
SP="${BREWO_SIGN_PROJECT:-$HOME/.app-installer/projects/com.social4hyq.brewo}"

export DEVECO_SDK_HOME="$SDK" HOS_SDK_HOME="$SDK" OHOS_BASE_SDK_HOME="$SDK"

echo "==> [1/4] 编译 native .so"
bash build-so.sh

echo "==> [2/4] hvigor 构建 HAP"
bash "$HVIGOR" --mode module -p product=default assembleHap --no-daemon

HAP="$HERE/entry/build/default/outputs/default/entry-default-unsigned.hap"
SO_DIR="$HERE/entry/src/main/cpp/libs/arm64-v8a"

echo "==> [3/4] 注入 .so 到 HAP"
STAGE=/data/storage/el2/base/cache/brewo-so-stage
rm -rf "$STAGE"; mkdir -p "$STAGE/libs/arm64-v8a"
found=0
for so in "$SO_DIR"/*.so; do
  [ -f "$so" ] || continue
  cp "$so" "$STAGE/libs/arm64-v8a/"
  found=$((found + 1)); echo "    + $(basename "$so")"
done
[ "$found" -gt 0 ] || { echo "ERROR: no .so found" >&2; exit 1; }
zip -q -d "$HAP" 'libs/*' 2>/dev/null || true
(cd "$STAGE" && zip -q -r "$HAP" libs)

echo "==> [4/4] 签名安装"
mkdir -p "$HERE/dist"
INSTALL_ARGS=()
if [[ "${BREWO_REGISTER_HARBOR:-0}" == 1 ]]; then INSTALL_ARGS+=(--no-start); fi
app-installer install --hap "$HAP" \
  --bundle-id com.social4hyq.brewo --app-name Brewo \
  --module entry --ability EntryAbility \
  --profile "$SP/build-profile.json5" \
  --signed-hap "$HERE/dist/brewo-signed.hap" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}

if [[ "${BREWO_REGISTER_HARBOR:-0}" == 1 ]]; then
  SERVICE_DIR="$HOME/.config/brewo"
  mkdir -p "$SERVICE_DIR"
  UNIT="$SERVICE_DIR/sh.brew.brewo-app.service"
  cat > "$UNIT" <<EOF
[Unit]
Description=Brewo Homebrew command service

[Service]
Type=simple
ExecStart="$HOME/.harmonybrew/opt/python@3.15/bin/python3.15" "$HERE/scripts/brewo-host.py" "--harbor"
Restart=on-failure
Environment="HOME=$HOME"
Environment="USER=${USER:-currentUser}"
Environment="TMPDIR=/data/storage/el2/base/cache"
StandardOutput=append:$HOME/.harmonybrew/var/log/brewo-host.log
StandardError=append:$HOME/.harmonybrew/var/log/brewo-host.log
EOF
  python3 "$HERE/scripts/brewo-host.py" --register-harbor --development-unit "$UNIT" --launch-app
fi

echo "DONE. HAP size: $(du -h "$HAP" | cut -f1)"
