#!/usr/bin/env bash
# 从源工程装配 Electron 内核资源到本工程。
#
# 为什么要这个脚本：Electron 内核二进制（约 183MB）与 resfile 运行时资源（约 18MB）
# 体积过大，不适合进 Git（见 .gitignore 中的 /electron/libs 与 resfile 规则）。
# 新克隆工程后必须先执行本脚本，才能构建出可运行的 HAP。
#
# 来源工程：
#   harmonypc-electron            —— 已完成 v37 装配的参考工程
#   harmonypc-electron-versions   —— 各版本 Electron 原始产物（版本对照）
#
# 用法：
#   bash scripts/assemble-resources.sh [--from <harmonypc-electron 路径>]
#
# 完成后会按 runtime-manifest.json 校验三个 .so 的 MD5。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

SOURCE_ROOT="/d/pi-workspace/harmonypc-electron"
if [ "${1:-}" = "--from" ]; then
  if [ -z "${2:-}" ]; then
    echo "ERROR: --from 需要一个路径参数，例如 --from /d/pi-workspace/harmonypc-electron" >&2
    exit 1
  fi
  SOURCE_ROOT="$2"
elif [ -n "${1:-}" ]; then
  SOURCE_ROOT="$1"
fi
SRC_HAP="${SOURCE_ROOT}/ohos_hap"

if ! command -v python >/dev/null 2>&1; then
  echo "ERROR: 需要 python 用于按 runtime-manifest.json 校验 MD5" >&2
  exit 1
fi

if [ ! -d "${SRC_HAP}" ]; then
  echo "ERROR: 源工程不存在：${SRC_HAP}" >&2
  echo "       请用 --from 指定 harmonypc-electron 的路径" >&2
  exit 1
fi

echo "==> [1/3] 复制 Electron 原生库 (electron/libs)"
for so in libelectron.so libadapter.so libffmpeg.so; do
  if [ ! -f "${SRC_HAP}/electron/libs/arm64-v8a/${so}" ]; then
    echo "ERROR: 源工程缺少 ${SRC_HAP}/electron/libs/arm64-v8a/${so}" >&2
    echo "       请确认源工程已解压 Electron v37.2.3 发行产物" >&2
    exit 1
  fi
done
mkdir -p electron/libs/arm64-v8a
cp -f "${SRC_HAP}/electron/libs/arm64-v8a/libelectron.so" electron/libs/arm64-v8a/
cp -f "${SRC_HAP}/electron/libs/arm64-v8a/libadapter.so" electron/libs/arm64-v8a/
cp -f "${SRC_HAP}/electron/libs/arm64-v8a/libffmpeg.so" electron/libs/arm64-v8a/

echo "==> [2/3] 复制 Electron 运行时资源 (web_engine resfile)"
RESFILE_DST="web_engine/src/main/resources/resfile"
mkdir -p "${RESFILE_DST}"
# 注意：resources/app 是本工程自有的 Electron 应用，绝不覆盖
for item in chrome_100_percent.pak chrome_200_percent.pak icudtl.dat resources.pak \
            snapshot_blob.bin v8_context_snapshot.bin electron locales vulkan; do
  if [ -e "${SRC_HAP}/web_engine/src/main/resources/resfile/${item}" ]; then
    rm -rf "${RESFILE_DST:?}/${item}"
    cp -a "${SRC_HAP}/web_engine/src/main/resources/resfile/${item}" "${RESFILE_DST}/"
  else
    echo "    跳过（源中不存在）: ${item}"
  fi
done

echo "==> [3/3] 按 runtime-manifest.json 校验 MD5"
python - "$PROJECT_ROOT" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / "runtime-manifest.json").read_text(encoding="utf-8"))
ok = True
for entry in manifest.get("so", []):
    target = root / entry["path"]
    if not target.exists():
        print(f"  MISSING {entry['path']}")
        ok = False
        continue
    digest = hashlib.md5(target.read_bytes()).hexdigest().upper()
    matched = digest == entry["md5"].upper()
    ok = ok and matched
    print(f"  {'OK  ' if matched else 'FAIL'} {entry['path']} md5={digest}")

libcxx = manifest.get("libcxx", {})
print(f"  INFO libcxx 声明来源：{libcxx.get('source', 'N/A')}（该 .so 未被任何二进制 DT_NEEDED 引用，故不装配）")
print("完成" if ok else "校验失败：请检查源工程版本是否为 v37.2.3")
sys.exit(0 if ok else 1)
PY

echo "装配完成。可执行 bash scripts/build.sh 构建。"
