# build-tools-36-aarch64

一个可重现的（基于网络的）构建 + 打包工作流，用于在 **aarch64 Linux** 上生成**可工作的 build-tools 36.0.0** 目录，其布局与官方 build-tools 保持一致。

本仓库包含：
- `scripts/` — 端到端的重现脚本（获取源码 → 打补丁 → 构建 → 安装 → 验证）
- `patches/` — 成功构建所需的最小补丁集
- `docs/` — 构建说明、错误手册和升级注意事项（含未来 37.0.0 的应对方法）
- `templates/android-sdk-tools-min/` — 我们所修改的关键上游文件的最小参考副本（可选，补丁为准）

## 快速开始（在 Debian 容器内执行，需要网络）

```bash
cd /root/workspace/build-tools-36-aarch64

# 0) 安装依赖
./scripts/00_prereq.sh

# 0.5) 自动安装 Android SDK + NDK（可选）
export ANDROID_SDK_ROOT=/root/workspace/android-sdk
./scripts/05_fetch_ndk_sdk.sh
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/29.0.14206865"  # 参见 scripts/env.sh

# 1) 获取源码
./scripts/10_fetch_sources.sh

# 2) 若 NDK 自带的 ld.lld 架构不兼容，可自行构建 lld（可选）
./scripts/20_build_lld.sh

# 3) 打补丁并构建 android-sdk-tools
./scripts/30_patch_and_build_sdk_tools.sh

# 4) 安装到 ANDROID_SDK_ROOT/build-tools/36.0.0
./scripts/40_install_build_tools_36.sh

# 5) 验证
./scripts/50_verify.sh