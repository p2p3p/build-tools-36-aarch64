# build-tools-36-aarch64 (Termux 内部存储版)

一个可重现的（基于网络的）构建 + 打包工作流，用于在 **Termux (aarch64 Android)** 上生成**可工作的 build-tools 36.0.0** 目录，布局与官方完全一致。

本仓库包含：
- `scripts/` — 端到端的重现脚本
- `patches/` — 成功构建所需的最小补丁集
- `docs/` — 构建说明、错误手册和升级注意事项
- `templates/android-sdk-tools-min/` — 关键上游文件的最小参考副本（可选）

## 快速开始（在 Termux 内执行）

```bash
# 1. 进入项目目录（以下所有脚本使用相对路径）
cd /data/data/com.termux/files/home/workspace/build-tools-36-aarch64

# 2. 安装依赖（Termux 使用 pkg，非 apt）
pkg update -y
pkg install -y python openjdk-17 git make cmake ninja patchelf binutils

# 3. 设置 Android SDK 绝对路径（内部存储，遵循官方 ANDROID_SDK_ROOT）
export ANDROID_SDK_ROOT=/data/data/com.termux/files/home/android-sdk

# 4. 可选：自动下载 SDK 和 NDK
./scripts/05_fetch_ndk_sdk.sh

# 5. 设置 NDK 绝对路径（根据实际下载的版本号调整）
export ANDROID_NDK_ROOT=/data/data/com.termux/files/home/android-sdk/ndk/29.0.14206865

# 6. 获取源码
./scripts/10_fetch_sources.sh

# 7. 可选：构建 lld（若 NDK 自带的 ld.lld 不兼容 aarch64）
./scripts/20_build_lld.sh

# 8. 打补丁并构建 android-sdk-tools
./scripts/30_patch_and_build_sdk_tools.sh

# 9. 安装到 $ANDROID_SDK_ROOT/build-tools/36.0.0
./scripts/40_install_build_tools_36.sh

# 10. 验证
./scripts/50_verify.sh