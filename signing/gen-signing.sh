#!/usr/bin/env bash
# ElectronShell 调试签名材料生成脚本（OpenHarmony 自签名体系）
#
# 用途：在没有华为 AGC 账号自动签名的情况下，使用 OpenHarmony SDK 自带的
#       hap-sign-tool + OpenHarmony.p12 生成一套本地调试签名材料：
#         - app-keystore.p12   应用签名私钥
#         - app-cert-chain.cer 应用证书链（叶子 -> OpenHarmony Application CA -> Root CA）
#         - profile.json       未签名 Provision Profile（绑定 bundleName 与设备 UDID）
#         - profile.p7b        已签名 Provision Profile
#
# 依赖：DevEco Studio 自带 jbr（keytool / java）与 OpenHarmony SDK toolchains/lib
#
# 用法：bash signing/gen-signing.sh [bundleName] [deviceUdid]

set -euo pipefail

DEVeCO_ROOT="${DEVECO_ROOT:-/d/oh-workspace/DevEco Studio}"
SDK_LIB="${SDK_LIB:-${DEVeCO_ROOT}/sdk/default/openharmony/toolchains/lib}"
KEYTOOL="${DEVeCO_ROOT}/jbr/bin/keytool.exe"
JAVA="${DEVeCO_ROOT}/jbr/bin/java.exe"
SIGN_TOOL="${SDK_LIB}/hap-sign-tool.jar"

BUNDLE_NAME="${1:-com.jkh.electronshell}"
DEVICE_UDID="${2:-084FE48364AAFE770B83C793762F0B39DE5F7A63C51500C0BCF18908AFCDD08C}"

STORE_PWD="Electron@2026"
OH_PWD="123456"
KEY_ALIAS="electronshell-debug-key"
SUBJECT="C=CN,O=OpenHarmony,OU=OpenHarmony Community,CN=ElectronShell Debug"
ISSUER="C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA"

OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$OUT_DIR"

echo "[1/5] 导出 OpenHarmony CA 证书"
"$KEYTOOL" -exportcert -rfc -alias "openharmony application ca" \
  -keystore "${SDK_LIB}/OpenHarmony.p12" -storepass "$OH_PWD" -storetype PKCS12 \
  -file sub-ca.cer >/dev/null
"$KEYTOOL" -exportcert -rfc -alias "openharmony application root ca" \
  -keystore "${SDK_LIB}/OpenHarmony.p12" -storepass "$OH_PWD" -storetype PKCS12 \
  -file root-ca.cer >/dev/null

echo "[2/5] 生成应用签名密钥对"
rm -f app-keystore.p12
"$JAVA" -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "$KEY_ALIAS" -keyPwd "$STORE_PWD" -keyAlg ECC -keySize NIST-P-256 \
  -keystoreFile "$OUT_DIR/app-keystore.p12" -keystorePwd "$STORE_PWD"

echo "[3/5] 生成应用证书链"
"$JAVA" -jar "$SIGN_TOOL" generate-app-cert \
  -keyAlias "$KEY_ALIAS" -keyPwd "$STORE_PWD" \
  -issuer "$ISSUER" -issuerKeyAlias "openharmony application ca" -issuerKeyPwd "$OH_PWD" \
  -subject "$SUBJECT" -validity 3650 -signAlg SHA256withECDSA \
  -rootCaCertFile "$OUT_DIR/root-ca.cer" -subCaCertFile "$OUT_DIR/sub-ca.cer" \
  -keystoreFile "$OUT_DIR/app-keystore.p12" -keystorePwd "$STORE_PWD" \
  -issuerKeystoreFile "${SDK_LIB}/OpenHarmony.p12" -issuerKeystorePwd "$OH_PWD" \
  -outForm certChain -outFile "$OUT_DIR/app-cert-chain.cer"

echo "[4/5] 生成未签名 profile.json"
"$JAVA" -jar "$SIGN_TOOL" generate-profile-cert >/dev/null 2>&1 || true
python - "$OUT_DIR" "$BUNDLE_NAME" "$DEVICE_UDID" <<'PY'
import json, sys, pathlib
out_dir, bundle, udid = sys.argv[1], sys.argv[2], sys.argv[3]

# 只取证书链中的叶子证书，并统一换行符为 \n（\r 会导致 hap-sign-tool base64 解析失败）
chain = pathlib.Path(out_dir, "app-cert-chain.cer").read_text().replace("\r\n", "\n")
end_marker = "-----END CERTIFICATE-----"
leaf = chain[: chain.index(end_marker) + len(end_marker)] + "\n"
pathlib.Path(out_dir, "app-leaf.cer").write_text(leaf)

profile = {
    "version-name": "1.0.0",
    "version-code": 1000000,
    "uuid": "7c2f4b1e-9a3d-4e58-b6a1-2d4c8f0e5a17",
    "validity": {"not-before": 1760000000, "not-after": 2080000000},
    "type": "debug",
    "bundle-info": {
        "developer-id": "OpenHarmony",
        "development-certificate": leaf,
        "bundle-name": bundle,
        "apl": "normal",
        "app-feature": "hos_normal_app",
    },
    "acls": {"allowed-acls": [""]},
    "permissions": {"restricted-permissions": [""]},
    "debug-info": {"device-ids": [udid], "device-id-type": "udid"},
    "issuer": "pki_internal",
}
pathlib.Path(out_dir, "profile.json").write_text(
    json.dumps(profile, indent=4, ensure_ascii=False) + "\n", newline="\n"
)
print("profile.json written:", bundle, udid)
PY

echo "[5/5] 签名 Profile"
"$JAVA" -jar "$SIGN_TOOL" sign-profile -mode localSign \
  -keyAlias "openharmony application profile debug" -keyPwd "$OH_PWD" \
  -profileCertFile "${SDK_LIB}/OpenHarmonyProfileDebug.pem" \
  -inFile "$OUT_DIR/profile.json" -signAlg SHA256withECDSA \
  -keystoreFile "${SDK_LIB}/OpenHarmony.p12" -keystorePwd "$OH_PWD" \
  -outFile "$OUT_DIR/profile.p7b"

echo "[verify] 校验 profile.p7b"
"$JAVA" -jar "$SIGN_TOOL" verify-profile \
  -inFile "$OUT_DIR/profile.p7b" -outFile "$OUT_DIR/verify-profile-result.json"

echo "完成：签名材料位于 $OUT_DIR"
