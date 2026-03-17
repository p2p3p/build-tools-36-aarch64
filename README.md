# build-tools-36-aarch64

A reproducible (network-based) build + packaging workflow to produce a **working build-tools 36.0.0** directory on **aarch64 Linux**, aligned to a typical official build-tools layout.

This repo contains:
- `scripts/` — end-to-end repro scripts (fetch → patch → build → install → verify)
- `patches/` — the minimal patch set required for the successful build
- `docs/` — build notes, error cookbook, and upgrade notes (incl. future 37.0.0)
- `templates/android-sdk-tools-min/` — minimal reference copies of the key upstream files we patched (optional; patch is canonical).

## Quick start (performed inside a Debian container, network required)

```bash
cd /root/workspace/build-tools-36-aarch64

# 0) prerequisites
./scripts/00_prereq.sh

# 0.5) install Android SDK + NDK automatically (optional)
export ANDROID_SDK_ROOT=/root/workspace/android-sdk
./scripts/05_fetch_ndk_sdk.sh
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/29.0.14206865"  # see scripts/env.sh

# 1) fetch sources
./scripts/10_fetch_sources.sh

# 2) build lld if your NDK ld.lld is broken-arch (optional)
./scripts/20_build_lld.sh

# 3) patch + build android-sdk-tools
./scripts/30_patch_and_build_sdk_tools.sh

# 4) install into ANDROID_SDK_ROOT/build-tools/36.0.0
./scripts/40_install_build_tools_36.sh

# 5) verify
./scripts/50_verify.sh
```

## Docs

- `docs/BUILD_NOTES.md` — errors encountered, fixes, and reasoning; includes an approach for future `build-tools 37.0.0`.
- `scripts/get_source.py` — archived helper script used for tag discovery/fetch workflows.

## Notes

- This is **not** an official Google build-tools distribution. It is a pragmatic, reproducible toolchain to satisfy AGP requirements on aarch64 Linux.
- If you want stronger reproducibility, pin source repos to specific commits in `scripts/10_fetch_sources.sh`.
