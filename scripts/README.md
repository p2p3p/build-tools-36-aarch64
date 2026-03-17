# scripts/

Repro scripts (network-based) to rebuild and install build-tools 36.0.0 for aarch64.

## Quick start (fresh Debian)

```bash
cd /root/workspace/build-tools-36-aarch64

# 0) deps
./scripts/00_prereq.sh

# 0.5) (optional) fetch Android SDK + NDK automatically
export ANDROID_SDK_ROOT=/root/workspace/android-sdk
./scripts/05_fetch_ndk_sdk.sh
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/29.0.14206865"  # see scripts/env.sh

# 1) fetch sources
./scripts/10_fetch_sources.sh

# 2) (optional) build lld if your NDK ld.lld is broken-arch
./scripts/20_build_lld.sh

# 3) patch + build android-sdk-tools
./scripts/30_patch_and_build_sdk_tools.sh

# 4) install into ANDROID_SDK_ROOT/build-tools/36.0.0
./scripts/40_install_build_tools_36.sh

# 5) verify
./scripts/50_verify.sh
```

If any path differs in your environment, adjust ANDROID_SDK_ROOT / ANDROID_NDK_ROOT.
