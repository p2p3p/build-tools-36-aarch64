#!/usr/bin/env bash
set -euo pipefail

# Apply our patch to android-sdk-tools and build tool binaries (aapt2/aidl/zipalign/etc).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="${ROOT_DIR}/work"
SDKTOOLS_DIR="${WS_DIR}/android-sdk-tools"
PATCH_FILE="${ROOT_DIR}/patches/android-sdk-tools-changes.patch"

: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to your NDK path}"

if [[ ! -d "${SDKTOOLS_DIR}/.git" ]]; then
  echo "ERROR: missing ${SDKTOOLS_DIR}. Run scripts/10_fetch_sources.sh first." >&2
  exit 1
fi

cd "${SDKTOOLS_DIR}"

# Apply patch idempotently
if git apply --check "${PATCH_FILE}" >/dev/null 2>&1; then
  git apply "${PATCH_FILE}"
  echo "[OK] patch applied"
else
  echo "[INFO] patch not applied (maybe already applied or base differs)." >&2
fi

# Build (the repo's build.py drives cmake+ninja)
# Most setups require ANDROID_NDK_ROOT.
python3 ./build.py --ndk "${ANDROID_NDK_ROOT}" --target=all

echo "[OK] build finished"
