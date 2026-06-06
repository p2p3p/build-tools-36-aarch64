# scripts/

可重现的（基于网络的）构建脚本，用于在 Termux (aarch64) 上构建并安装 build-tools 36.0.0。所有外部路径均为绝对路径，遵循 Android 官方标准。

## 快速开始（假设已进入项目根目录）

```bash
# 进入脚本目录（相对路径）
cd scripts

# 1. 安装依赖（Termux 使用 pkg）
pkg update -y
pkg install -y python openjdk-17 git make cmake ninja patchelf binutils

# 2. 设置 Android SDK 绝对路径
export ANDROID_SDK_ROOT=/data/data/com.termux/files/home/android-sdk

# 3. 可选：自动下载 SDK 和 NDK
./05_fetch_ndk_sdk.sh

# 4. 设置 NDK 绝对路径（根据实际版本调整）
export ANDROID_NDK_ROOT=/data/data/com.termux/files/home/android-sdk/ndk/29.0.14206865

# 5. 获取源码
./10_fetch_sources.sh

# 6. 可选：构建 lld
./20_build_lld.sh

# 7. 构建 android-sdk-tools
./30_patch_and_build_sdk_tools.sh

# 8. 安装到 $ANDROID_SDK_ROOT/build-tools/36.0.0
./40_install_build_tools_36.sh

# 9. 验证
./50_verify.sh