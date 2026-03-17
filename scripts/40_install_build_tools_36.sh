#!/usr/bin/env bash
set -euo pipefail

# Install built artifacts into an Android SDK build-tools/36.0.0 directory
# and align directory layout to match a typical official build-tools folder.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="${ROOT_DIR}/work"
SDKTOOLS_DIR="${WS_DIR}/android-sdk-tools"

: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to your Android SDK path, e.g. /root/workspace/android-sdk}"

source "${ROOT_DIR}/scripts/env.sh"

BT35="${ANDROID_SDK_ROOT}/build-tools/${DONOR_BUILD_TOOLS_VERSION}"
BT36="${ANDROID_SDK_ROOT}/build-tools/36.0.0"

if [[ ! -d "${BT35}" ]]; then
  echo "ERROR: ${BT35} not found (used as donor for apksigner/d8/etc)." >&2
  exit 1
fi

mkdir -p "${BT36}"

# 1) Copy our built binaries
# NOTE: Adjust paths if upstream repo changes its output layout.
BIN_DIR_CANDIDATES=(
  "${SDKTOOLS_DIR}/build/aarch64/bin"
  "${SDKTOOLS_DIR}/build/aarch64/build-tools/bin"
  "${SDKTOOLS_DIR}/build/aarch64/build-tools"
)

FOUND_BIN_DIR=""
for d in "${BIN_DIR_CANDIDATES[@]}"; do
  if [[ -d "$d" ]]; then FOUND_BIN_DIR="$d"; break; fi
done

if [[ -z "${FOUND_BIN_DIR}" ]]; then
  echo "ERROR: cannot find built bin dir under ${SDKTOOLS_DIR}/build/aarch64" >&2
  echo "Please inspect build output and update scripts/40_install_build_tools_36.sh" >&2
  exit 1
fi

echo "[INFO] using built output: ${FOUND_BIN_DIR}"

# aapt2 is the key
cp -a "${FOUND_BIN_DIR}/aapt2" "${BT36}/aapt2"

# Optional tools if present
for t in aapt aidl zipalign split-select; do
  if [[ -f "${FOUND_BIN_DIR}/${t}" ]]; then
    cp -a "${FOUND_BIN_DIR}/${t}" "${BT36}/${t}"
  fi
done

# 2) Copy donor files from 35.0.1 to align official layout
for t in apksigner d8 dexdump core-lambda-stubs.jar NOTICE.txt runtime.properties package.xml source.properties; do
  if [[ -e "${BT35}/${t}" ]]; then
    cp -a "${BT35}/${t}" "${BT36}/${t}"
  fi
done

if [[ -d "${BT35}/lib" ]]; then
  mkdir -p "${BT36}/lib"
  rsync -a "${BT35}/lib/" "${BT36}/lib/"
fi

# 3) Ensure revision fields say 36.0.0 (minimal requirement for AGP discovery)
# source.properties
if [[ -f "${BT36}/source.properties" ]]; then
  sed -i 's/^Pkg\.Revision=.*/Pkg.Revision=36.0.0/' "${BT36}/source.properties" || true
else
  cat >"${BT36}/source.properties" <<'EOF'
Pkg.Desc=Android SDK Build-Tools
Pkg.Revision=36.0.0
EOF
fi

# package.xml (best-effort)
if [[ -f "${BT36}/package.xml" ]]; then
  # Replace common revision patterns
  sed -i 's/<major>[0-9]\+<\/major>/<major>36<\/major>/g; s/<minor>[0-9]\+<\/minor>/<minor>0<\/minor>/g; s/<micro>[0-9]\+<\/micro>/<micro>0<\/micro>/g' "${BT36}/package.xml" || true
fi

chmod -R a+rX "${BT36}" || true

echo "[OK] installed to ${BT36}"
