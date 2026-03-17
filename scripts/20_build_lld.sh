#!/usr/bin/env bash
set -euo pipefail

# Build lld (ld.lld) using the Android NDK toolchain.
# This is used when the NDK-shipped ld.lld is wrong-arch / broken.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="${ROOT_DIR}/work"
LLVM_DIR="${WS_DIR}/llvm-project"

: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to your NDK path, e.g. /root/workspace/android-sdk/ndk/29.0.xxxxxxxx}"

# NDK host clang path (adjust if needed)
CLANG="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
CLANGXX="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"

if [[ ! -x "${CLANG}" ]]; then
  echo "ERROR: clang not found/executable: ${CLANG}" >&2
  exit 1
fi

BUILD_DIR="${WS_DIR}/lld-build"
mkdir -p "${BUILD_DIR}"

cmake -S "${LLVM_DIR}/llvm" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS=lld \
  -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_ZLIB=ON \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DCMAKE_C_COMPILER="${CLANG}" \
  -DCMAKE_CXX_COMPILER="${CLANGXX}"

ninja -C "${BUILD_DIR}" lld

OUT_LLD="${BUILD_DIR}/bin/ld.lld"
if [[ ! -f "${OUT_LLD}" ]]; then
  echo "ERROR: build did not produce ${OUT_LLD}" >&2
  exit 1
fi

file "${OUT_LLD}"

echo "[OK] built: ${OUT_LLD}"

echo "To install into NDK (backup first):"
echo "  cp -a ${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld{,.bak}"
echo "  cp -a ${OUT_LLD} ${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld"
