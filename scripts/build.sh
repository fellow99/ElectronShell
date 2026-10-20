#!/usr/bin/env bash
# ElectronShell 构建脚本
#
# 签名策略（两选一，脚本自动识别）：
#   1. build-profile.json5 中存在 app.signingConfigs 且产品绑定了 signingConfig
#      -> 由 hvigor 的 SignHap 任务完成签名，产物为 electron-default-signed.hap；
#   2. 未配置 signingConfigs
#      -> hvigor 只产出 electron-default-unsigned.hap，
#         再由本脚本调用 SDK 的 hap-sign-tool 用 signing/ 目录材料签名。
#
# 推荐方式 1（DevEco Studio > Project Structure > Signing Configs > 自动签名），
# 因为 HarmonyOS 真机只接受华为 AGC 签发的 profile。
#
# 用法：bash scripts/build.sh [debug|release]

set -euo pipefail

BUILD_MODE="${1:-debug}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

DEVECO_ROOT="${DEVECO_ROOT:-/d/oh-workspace/DevEco Studio}"
SDK_LIB="${SDK_LIB:-${DEVECO_ROOT}/sdk/default/openharmony/toolchains/lib}"
JAVA="${DEVECO_ROOT}/jbr/bin/java.exe"
SIGN_TOOL="${SDK_LIB}/hap-sign-tool.jar"
HVIGORW="${HVIGORW:-D:\\oh-workspace\\command-line-tools\\bin\\hvigorw.bat}"
NODE_HOME="${NODE_HOME:-${DEVECO_ROOT}/tools/node}"

SIGN_DIR="$PROJECT_ROOT/signing"
KEY_ALIAS="electronshell-debug-key"
STORE_PWD="Electron@2026"
COMPATIBLE_VERSION=20

OUT_DIR="$PROJECT_ROOT/electron/build/default/outputs/default"
UNSIGNED_HAP="$OUT_DIR/electron-default-unsigned.hap"
SIGNED_HAP="$OUT_DIR/electron-default-signed.hap"

export PATH="$NODE_HOME:/d/oh-workspace/command-line-tools/bin:$PATH"
unset NODE_OPTIONS || true

echo "==> [1/2] hvigor assembleHap ($BUILD_MODE)"
cmd //c "$HVIGORW assembleHap --mode module -p product=default -p buildMode=$BUILD_MODE --no-daemon"

if [ -f "$SIGNED_HAP" ]; then
  echo "==> [2/2] 已由 hvigor signingConfig 完成签名，跳过手动签名"
  ls -la "$SIGNED_HAP"
  echo "构建完成：$SIGNED_HAP"
  exit 0
fi

if [ ! -f "$UNSIGNED_HAP" ]; then
  echo "ERROR: 未找到产物 $UNSIGNED_HAP" >&2
  exit 1
fi

echo "==> [2/2] hap-sign-tool sign-app（本地调试签名）"
"$JAVA" -jar "$SIGN_TOOL" sign-app -mode localSign \
  -keyAlias "$KEY_ALIAS" -keyPwd "$STORE_PWD" \
  -appCertFile "$SIGN_DIR/app-cert-chain.cer" \
  -profileFile "$SIGN_DIR/profile.p7b" \
  -inFile "$UNSIGNED_HAP" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$SIGN_DIR/app-keystore.p12" -keystorePwd "$STORE_PWD" \
  -outFile "$SIGNED_HAP" \
  -compatibleVersion "$COMPATIBLE_VERSION" \
  -signCode 1

ls -la "$SIGNED_HAP"
echo "构建完成：$SIGNED_HAP"
echo "注意：该产物使用本地 OpenHarmony 自签名，可安装于 OpenHarmony 设备；"
echo "      HarmonyOS 真机请使用 DevEco 自动签名（华为 AGC profile）。"
