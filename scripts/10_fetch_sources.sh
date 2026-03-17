#!/usr/bin/env bash
set -euo pipefail

# Fetch sources needed to reproduce the build.
# Network required.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="${ROOT_DIR}/work"
AOSPROOT="${WS_DIR}/aosp"
SDKTOOLS_DIR="${WS_DIR}/android-sdk-tools"
LLVM_DIR="${WS_DIR}/llvm-project"

mkdir -p "${WS_DIR}"

# 1) android-sdk-tools
if [[ ! -d "${SDKTOOLS_DIR}/.git" ]]; then
  git clone https://github.com/lzhiyong/android-sdk-tools.git "${SDKTOOLS_DIR}"
fi

# Optional: pin to a known commit for reproducibility (fill in if you want hard pinning)
# (cd "${SDKTOOLS_DIR}" && git checkout <COMMIT>)

# 2) llvm-project (for building lld/ld.lld if the NDK host binaries are broken)
if [[ ! -d "${LLVM_DIR}/.git" ]]; then
  git clone --depth=1 https://github.com/llvm/llvm-project.git "${LLVM_DIR}"
fi

# 3) AOSP checkout helper (repo). We keep this as a doc-driven step because
#    manifest/tag choices may evolve.
#    The bundled get_source.py is provided as the entrypoint.

echo "[OK] sources fetched under: ${WS_DIR}"
echo "Next: run scripts/get_source.py (see notes) if you need AOSP tag operations."
