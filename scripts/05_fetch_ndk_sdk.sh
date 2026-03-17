#!/usr/bin/env bash
set -euo pipefail

# Fetch/install Android SDK cmdline-tools + Build-Tools donor + NDK into a target ANDROID_SDK_ROOT.
# Network required.
# This is a convenience script to reduce manual setup on a fresh machine.

: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT (target install dir), e.g. /root/workspace/android-sdk}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DL_DIR="${ROOT_DIR}/downloads"
mkdir -p "${DL_DIR}" "${ANDROID_SDK_ROOT}"

# --------- CONFIG (centralized in scripts/env.sh) ---------
source "${ROOT_DIR}/scripts/env.sh"
CMDLINE_TOOLS_ZIP="${DL_DIR}/commandlinetools.zip"
DONOR_BUILD_TOOLS="${DONOR_BUILD_TOOLS_VERSION}"
NDK_VERSION="${NDK_VERSION}"
PLATFORM="${ANDROID_PLATFORM}"
CMDLINE_TOOLS_ZIP_URL="${CMDLINE_TOOLS_ZIP_URL}"
# ---------------------------------------------------------

# 1) cmdline-tools
if [[ ! -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest" ]]; then
  echo "[INFO] downloading cmdline-tools..."
  curl -L "${CMDLINE_TOOLS_ZIP_URL}" -o "${CMDLINE_TOOLS_ZIP}" --retry 3 --retry-delay 2
  mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"
  tmpdir="${DL_DIR}/cmdline-tools-unzip"
  rm -rf "$tmpdir" && mkdir -p "$tmpdir"
  unzip -q "${CMDLINE_TOOLS_ZIP}" -d "$tmpdir"
  # zip contains cmdline-tools/; move it to latest/
  rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
  mv "$tmpdir/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
fi

SDKMANAGER="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "${SDKMANAGER}" ]]; then
  echo "ERROR: sdkmanager not found at ${SDKMANAGER}" >&2
  exit 1
fi

export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT
export PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${PATH}"

# 2) accept licenses (best-effort)
yes | sdkmanager --licenses >/dev/null || true

# 3) install packages
sdkmanager \
  "platform-tools" \
  "build-tools;${DONOR_BUILD_TOOLS}" \
  "platforms;${PLATFORM}" \
  "ndk;${NDK_VERSION}"

echo "[OK] installed SDK packages under ${ANDROID_SDK_ROOT}"
echo "Set ANDROID_NDK_ROOT to: ${ANDROID_SDK_ROOT}/ndk/${NDK_VERSION}"
