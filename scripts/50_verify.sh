#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT}"
BT36="${ANDROID_SDK_ROOT}/build-tools/36.0.0"

echo "== file layout =="
ls -la "${BT36}" | sed -n '1,200p'

echo "== aapt2 version =="
"${BT36}/aapt2" version || true

echo "== smoke: aapt2 help =="
"${BT36}/aapt2" --help >/dev/null

echo "[OK] basic verification done"

echo "Optional: verify with a real Android project (recommended):"
echo "  cd /path/to/your-project && ./gradlew :app:assembleRelease --no-daemon"
