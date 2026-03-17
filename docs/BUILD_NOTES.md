# BUILD_NOTES - build-tools 36.0.0 (aarch64)

本文记录：在 **aarch64 Linux 主机**上，为了让 **AGP 9.1+** 可用，如何一步步做出“可运行的 build-tools 36.0.0”，以及过程中遇到的典型报错与修复思路。

> 关键词：AGP 9.1.0、Build Tools 36.0.0、aapt2、Exec format error、NDK side-by-side 29、C++20/libc++、androidfw、liblog。

---

## 1. 背景与硬约束

- **AGP 9.1+ 强制 Build Tools >= 36.0.0**。
- 官方 build-tools 36.0.0 在该主机上不可用（常见是 `Exec format error` / host 架构不匹配）。
- 目标不是“源码洁癖”，而是：
  1) 让 `build-tools/36.0.0/` 在 SDK 目录下被 AGP 识别为已安装；
  2) 其中 **aapt2 必须能在 aarch64 主机执行**；
  3) `./gradlew :app:assembleRelease --no-daemon` 能成功。

---

## 2. 总体路线（分段）

### 2.1 修复 NDK 29（地基）

症状（典型）：
- `clang-21: error: unable to execute command: posix_spawn failed: Exec format error`
- 链接时 `ld.lld` / `lld` 直接 `Exec format error`
- `llvm-ranlib: 1: llvm-ar: not found`（脚本/伪文件问题）
- `llvm-strip: 1: llvm-objcopy: not found`（同上）

做法（原则）：
- **保留 sysroot/headers/库**，逐个修 host bin。
- clang wrapper 改为 `exec clang-21`。
- `ld.lld` 用自编的 `lld` 替换正确架构。
- `llvm-ranlib` 改为脚本：`exec "$DIR/llvm-ar" s "$@"`。
- `llvm-strip` 改为脚本：`exec "$DIR/llvm-objcopy" --strip-all "$@"`。

### 2.2 交叉编译 android-sdk-tools：先把 aapt2 编出来

- 使用 `lzhiyong/android-sdk-tools` 的 `build.py` + cmake/ninja。
- 主战场：AOSP `androidfw` 在 C++20/libc++ 下的模板/迭代器兼容问题，以及缺失平台私有头。

典型报错：
- `fatal error: 'android_content_res.h' file not found`
- `std::inplace_merge` + proxy iterator 导致 `swap/iter_swap` 模板报错
- C++23 API：`std::string::resize_and_overwrite` 不存在

关键修复思路：
- `AssetManager2.cpp`：避免 `std::inplace_merge(CombinedIterator...)`，改为手写 merge（临时 vector 合并再 swap）。
- 对缺头/私有 API：尽量 include repo 内可替代头；不可用的 platform-only 逻辑用 feature flag 禁用。
- C++23 API 用兼容写法替换。

### 2.3 修复链接期 missing symbols（补齐 cmake 源文件列表）

典型报错：
- `undefined symbol: aapt::FlaggedXmlVersioner::Process(...)`
- `undefined symbol: android::findParentLocalePackedKey(...)`

原因：cmake 源文件列表漏了 AOSP 新增/拆分文件。

修复：
- `build-tools/aapt2.cmake`：补 `FlaggedXmlVersioner.cpp`、`FlagNotEnabledResourceRemover.cpp`。
- `lib/libandroidfw.cmake`：补 `LocaleDataLookup.cpp`。

### 2.4 让 AGP 认可 build-tools/36.0.0 已安装（过完整性检查）

典型报错：
- `Failed to find Build Tools revision 36.0.0`
- `Installed Build Tools revision 36.0.0 is corrupted`
- `missing DEXDUMP` / `missing core-lambda-stubs.jar`

修复：
- 创建 `$ANDROID_SDK_ROOT/build-tools/36.0.0/`。
- 补 `package.xml`、`source.properties`（revision/path/display-name 对齐）。
- 补 `core-lambda-stubs.jar`。
- `dexdump` 初期可以先占位，之后用已有版本补齐。

### 2.5 最后一公里：aapt2 运行时崩溃（core dump）

现象：
- Gradle 只报 `AAPT2 ... Unexpected error during link`，stderr 为空。
- 开启 core：`ulimit -c unlimited` 后生成 core 文件。

定位：
- 用 gdb 查看 core，发现栈在 `__android_log_logd_logger()` 中无限递归。

根因：
- 我们对 `liblog` 的 fallback 写法错误：
  - `__android_log_logd_logger()` 在 API<37 分支又调用回 `__android_log_write_log_message()`
  - 后者又通过 `logger_function` 调回 `__android_log_logd_logger()`
  - 造成无限递归 → SIGSEGV。

修复：
- `logger_write.cpp` 中 API<37 分支改为直接 `__android_log_stderr_logger(log_message)`。
- 重新构建 aapt2，并覆盖 SDK `36.0.0/aapt2`。

结果：
- `:app:processReleaseResources` 成功
- `:app:assembleRelease --no-daemon` 成功

---

## 3. 经验与建议（个人总结）

1) **先让工具链可信**：NDK side-by-side 在 aarch64 环境可能“装出来但不可用”，必须先验证每个 host bin。

2) **用“最短闭环”驱动**：不要一开始就追求 build-tools/platform-tools 全家桶；先把 AGP 真正在用的链路（aapt2 link）跑通。

3) **遇到“stderr 空白退出”就开 core dump**：比盲猜快一个数量级。

4) **AOSP 源码在 standalone 构建里，cmake 源文件列表经常落后**：出现 undefined symbol，优先检查“这个 cpp 根本没编进来”。

5) **不要迷信 -static-libstdc++**：NDK clang + libc++_static 场景，这个 flag 很容易把 C++ runtime 搞坏。

---

## 4. 当前产物状态

`build-tools/36.0.0` 已包含：
- aarch64 可执行：`aapt2`（自编）、`aapt`（自编）、`aidl`（自编）、`zipalign`（自编）、`split-select`（自编）
- 目录结构对齐：`package.xml`、`source.properties`、`NOTICE.txt`、`runtime.properties`、`core-lambda-stubs.jar`、`lib/`、`d8`、`apksigner`、`dexdump`

其中 `d8/apksigner/lib/*.jar/dexdump` 为复用本机已有 build-tools（35.0.1）补齐结构与完整性检查。


---

## 5. 从零复现（命令清单，尽量可复制粘贴）

> 说明：以下以路径约定为例，按你当前环境：
> - SDK: `$ANDROID_SDK_ROOT`
> - NDK: `$ANDROID_NDK_ROOT`
> - android-sdk-tools repo: `$ANDROID_SDK_ROOT-tools`
> - 目标工程: 你的任意 Android 工程目录（例如 `/path/to/your-project`）
>
> 其中“NDK 29 混架构修复（clang/lld/ranlib/strip）”在不同机器可能不同；这里给出最终关键点和验证命令。

### 5.1 准备 build-tools 36.0.0 目录骨架

```bash
mkdir -p $ANDROID_SDK_ROOT/build-tools/36.0.0
```

### 5.2 确保 NDK host 工具可用（验证）

```bash
NDK=$ANDROID_NDK_ROOT
BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

file $BIN/clang-21
file $BIN/ld.lld
file $BIN/lld
file $BIN/llvm-ar
file $BIN/llvm-ranlib
file $BIN/llvm-objcopy
file $BIN/llvm-strip
```

期望：它们都是 aarch64 可执行（至少 `clang-21/lld/ld.lld` 必须能执行）。

如果发现：
- `llvm-strip` 内容是一个词（比如 `llvm-objcopy`）

修复为脚本：

```bash
cat > $BIN/llvm-strip <<'SH'
#!/usr/bin/env sh
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$DIR/llvm-objcopy" --strip-all "$@"
SH
chmod +x $BIN/llvm-strip
```

### 5.3 准备 android-sdk-tools 补丁

```bash
cd $ANDROID_SDK_ROOT-tools
# 确保在正确版本上
git rev-parse HEAD

# 应用补丁（来自本 kit）
# 假设你把 build-tools-36-aarch64 放在 /root/workspace/
PATCH=/root/workspace/build-tools-36-aarch64/patches/android-sdk-tools-changes.patch

git apply $PATCH
```

### 5.4 构建 build-tools（aapt2 关键）

```bash
cd $ANDROID_SDK_ROOT-tools
python3 build.py \
  --ndk=$ANDROID_NDK_ROOT \
  --abi=arm64-v8a \
  --api=30 \
  --build=build/aarch64 \
  --job=2 \
  --protoc=$ANDROID_SDK_ROOT-tools/src/protobuf/build/protoc \
  --target=all
```

产物位置：
- `$ANDROID_SDK_ROOT-tools/build/aarch64/bin/build-tools/aapt2`

### 5.5 安装到 SDK build-tools/36.0.0

```bash
cp -a $ANDROID_SDK_ROOT-tools/build/aarch64/bin/build-tools/* \
  $ANDROID_SDK_ROOT/build-tools/36.0.0/
```

### 5.6 补齐 AGP 完整性检查所需的 metadata 与常见文件

```bash
# 从本机已有的 35.0.1 复用一些“目录结构对齐”文件
BT35=$ANDROID_SDK_ROOT/build-tools/35.0.1
BT36=$ANDROID_SDK_ROOT/build-tools/36.0.0

cp -a $BT35/core-lambda-stubs.jar $BT36/
cp -a $BT35/dexdump $BT36/
cp -a $BT35/apksigner $BT36/
cp -a $BT35/d8 $BT36/
cp -a $BT35/runtime.properties $BT36/ || true
cp -a $BT35/NOTICE.txt $BT36/ || true
cp -a $BT35/lib $BT36/ || true

# package.xml / source.properties（最简：从 35.0.1 拷贝后替换版本号）
cp -a $BT35/package.xml $BT36/package.xml
cp -a $BT35/source.properties $BT36/source.properties
sed -i 's/Pkg\.Revision=35\.0\.1/Pkg.Revision=36.0.0/g' $BT36/source.properties

python3 - <<'PY'
from pathlib import Path
p=Path('$ANDROID_SDK_ROOT/build-tools/36.0.0/package.xml')
s=p.read_text()
s=s.replace('build-tools;35.0.1','build-tools;36.0.0')
s=s.replace('Android SDK Build-Tools 35.0.1','Android SDK Build-Tools 36.0.0')
s=s.replace('<revision><major>35</major><minor>0</minor><micro>1</micro></revision>',
            '<revision><major>36</major><minor>0</minor><micro>0</micro></revision>')
p.write_text(s)
PY
```

### 5.7 让 AGP 使用本地 aapt2（避免下载 x86_64 aapt2）

在项目 `gradle.properties`：

```properties
android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/36.0.0/aapt2
```

并移除/注释掉 `app/build.gradle` 里的低版本 `buildToolsVersion`（AGP 9.1 会忽略且报警）。

### 5.8 验证

```bash
cd /path/to/your-project
export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
./gradlew :app:assembleRelease --no-daemon
```

如果出现 `AAPT2 ... Unexpected error during link` 且 stderr 为空：

```bash
ulimit -c unlimited
./gradlew :app:processReleaseResources --no-daemon --info || true
ls -la core* || true
```

用 gdb 查看 core（需要安装 gdb）：

```bash
apt-get update && apt-get install -y gdb

gdb -q $ANDROID_SDK_ROOT/build-tools/36.0.0/aapt2 ./core \
  -ex 'set pagination off' \
  -ex 'thread apply all bt' \
  -ex 'quit'
```


---

## 6. 关键补丁点 Checklist（按文件逐条说明）

> 目的：以后回头看时，不需要重读长日志；按文件就能知道“为什么改、解决什么错误”。

### 6.1 android-sdk-tools/CMakeLists.txt

- **过滤 / 避免 `-static-libstdc++`**（或避免其带来的 C++ runtime 选择问题）
  - **症状**：链接 aapt2 时出现大量 undefined symbol：
    - `operator new/delete`、`__cxa_*`、`typeinfo` 等
  - **结论**：NDK clang + libc++_static 场景下，`-static-libstdc++` 会导致链接到不匹配的运行时/缺少 cxxabi，最终炸链。

- **显式追加 `-lc++abi -lunwind` 到 linker flags**（在 standalone mostly-static 链接里更稳）
  - **症状**：依旧缺 `__cxa_*` 或 RTTI/vtable。
  - **做法**：把它们加到 `CMAKE_EXE_LINKER_FLAGS/SHARED/MODULE`。

### 6.2 android-sdk-tools/src/logging/liblog/logger_write.cpp  ✅（最终关键）

- **修复 `__android_log_logd_logger()` API<37 分支的无限递归**
  - **症状**：Gradle 报 `AAPT2 ... Unexpected error during link`，stderr 为空；开启 core 后 `gdb` 显示栈在 `__android_log_logd_logger()` 无限重复。
  - **根因**：
    - `__android_log_write_log_message()` 会调用 `logger_function(log_message)`
    - 默认 `logger_function == __android_log_logd_logger`
    - 如果 `__android_log_logd_logger()` 又回调 `__android_log_write_log_message()` 就会无限递归。
  - **修复**：API<37 时改为 `__android_log_stderr_logger(log_message)`（不依赖 logd，且不递归）。
  - **效果**：aapt2 不再 core dump，`processReleaseResources/assembleRelease` 通过。

### 6.3 android-sdk-tools/src/base/libs/androidfw/AssetManager2.cpp

- **绕开 libc++ C++20 下 `std::inplace_merge` + proxy iterator 的模板地狱**
  - **症状**：
    - `std::inplace_merge` 触发 `iter_swap/swap` 模板报错
    - 或 `std::less<>` 比较失败（`Theme::Entry` 不可比）
  - **做法**：
    - 直接把 inplace_merge 换成“手写 merge”（临时 vector 合并后 swap 回 `keys_/entries_`）
  - **取舍**：牺牲一点性能/内存换取可编译性；这是 build-tools 构建可接受的。

### 6.4 android-sdk-tools/src/base/libs/androidfw/Util.cpp

- **替换 `std::string::resize_and_overwrite`（C++23）**
  - **症状**：当前 NDK libc++ 不提供该 API，编译失败。
  - **修复**：改用 `resize + data()` 写入的兼容实现。

### 6.5 android-sdk-tools/build-tools/aapt2.cmake

- **补齐漏编进 `libaapt2` 的源文件**
  - **症状**：链接 `aapt2` 时 undefined：
    - `aapt::FlaggedXmlVersioner::Process(...)`
    - `aapt::FlagNotEnabledResourceRemover::Consume(...)` 以及 vtable
  - **修复**：把以下 cpp 加进 `add_library(libaapt2 STATIC ...)`：
    - `link/FlaggedXmlVersioner.cpp`
    - `link/FlagNotEnabledResourceRemover.cpp`

### 6.6 android-sdk-tools/build-tools/aidl.cmake

- **补 include 路径：`${SRC}/aidl/include`**
  - **症状**：`fatal error: 'aidl/transaction_ids.h' file not found`
  - **修复**：在 `target_include_directories(aidl ...)` 中加入 `${SRC}/aidl/include`。

### 6.7 android-sdk-tools/lib/libandroidfw.cmake

- **补齐 LocaleDataLookup.cpp**
  - **症状**：链接 `aapt2` 时 undefined：
    - `android::findParentLocalePackedKey`
    - `android::isLocaleRepresentative`
    - `android::lookupLikelyScript`
    - `android::getMaxAncestorTreeDepth`
  - **修复**：将 `${SRC}/base/libs/androidfw/LocaleDataLookup.cpp` 加进 `libandroidfw` 源列表。

### 6.8 NDK side-by-side 29 的 host bin 修复（不在 android-sdk-tools patch 内，但属于必需）

- `clang/clang++` wrapper 指向正确的 `clang-21`
- `lld/ld.lld` 替换为正确架构可执行
- `llvm-ranlib` 修为脚本调用 `llvm-ar s`
- `llvm-strip` 修为脚本调用 `llvm-objcopy --strip-all`

### 6.9 SDK 目录完整性补齐（build-tools/36.0.0）

- `package.xml`：revision/path/display-name 改为 36.0.0
- `source.properties`：`Pkg.Revision=36.0.0`
- 补齐 AGP 检查项：`core-lambda-stubs.jar`、`dexdump`、以及尽量对齐的 `d8/apksigner/lib/*.jar/NOTICE.txt/runtime.properties`
- `gradle.properties` 中设置：
  - `android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/36.0.0/aapt2`


---

## 7. 源码拉取（android-sdk-tools / llvm-project）

### 7.1 拉取 android-sdk-tools

> 目标：获取用于交叉编译 build-tools（尤其 aapt2）的源码与构建脚本。

```bash
cd /root/workspace
# 例：如果你还没 clone
#（仓库地址按你实际使用的来源为准；这里示例 lzhiyong/android-sdk-tools）
git clone https://github.com/lzhiyong/android-sdk-tools.git
cd android-sdk-tools

# 建议固定到某个 commit/tag，避免上游变动导致 patch 失效
git rev-parse HEAD
```

如果你使用本 kit 的 patch：

```bash
git apply /root/workspace/build-tools-36-aarch64/patches/android-sdk-tools-changes.patch
```

### 7.2 拉取 AOSP llvm-project（用于编 lld 修复 NDK linkers）

> 目标：构建 aarch64 可执行的 `lld`，替换 NDK 里错误架构的 `lld/ld.lld`。

```bash
cd /root/workspace
# shallow clone 即可
git clone --depth=1 https://android.googlesource.com/toolchain/llvm-project llvm-project
```

---

## 8. 使用 NDK 编译 lld/ld.lld（完整步骤）

> 背景：NDK side-by-side 在 aarch64 主机上可能出现 host 工具错架构（`ld.lld` x86_64），导致 clang 链接阶段 `posix_spawn Exec format error`。
> 解决：自己编一个 host 可执行的 `lld`，替换 NDK 里的 `lld/ld.lld`。

### 8.1 安装依赖（Debian）

```bash
apt-get update
apt-get install -y cmake ninja-build git python3
```

### 8.2 配置与编译（仅 lld，Release）

```bash
cd /root/workspace

LLVM_SRC=/root/workspace/llvm-project
LLVM_BUILD=/root/workspace/llvm-lld-build

rm -rf "$LLVM_BUILD"
mkdir -p "$LLVM_BUILD"
cd "$LLVM_BUILD"

cmake -G Ninja \
  -S "$LLVM_SRC/llvm" \
  -B "$LLVM_BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS=lld \
  -DLLVM_TARGETS_TO_BUILD="AArch64" \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF

ninja lld
```

编完产物一般在：
- `$LLVM_BUILD/bin/lld`

验证：

```bash
file $LLVM_BUILD/bin/lld
$LLVM_BUILD/bin/lld --version || true
```

### 8.3 替换 NDK 内的 lld/ld.lld（先备份再替换）

```bash
NDK=$ANDROID_NDK_ROOT
NDK_BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

# 备份
cp -a $NDK_BIN/lld $NDK_BIN/lld.bak 2>/dev/null || true
cp -a $NDK_BIN/ld.lld $NDK_BIN/ld.lld.bak 2>/dev/null || true

# 替换
cp -a $LLVM_BUILD/bin/lld $NDK_BIN/lld
chmod +x $NDK_BIN/lld
ln -sf lld $NDK_BIN/ld.lld

# 验证链接不再 Exec format error
cat >/tmp/t.c <<'C'
int main(){return 0;}
C
$NDK_BIN/clang --target=aarch64-none-linux-android30 /tmp/t.c -o /tmp/t
file /tmp/t
```

如果这里成功产出 aarch64 ELF 且无 `Exec format error`，说明 linker 修复到位。


---

## 9. 如何找到/确认 Android 16 (android-16.0.0_r4) 这类 tag

AOSP 的 tag 命名通常是：
- `android-<主版本>.<次版本>.<补丁>_r<序号>`

例如：
- `android-16.0.0_r4`

### 9.1 用命令列出远端 tag（Git）

如果你已经有某个 AOSP 仓库（例如 frameworks/base 或 build/make 等）clone 在本地：

```bash
cd /path/to/aosp-repo
# 查看远端 tags（不一定全部拉到本地）
git ls-remote --tags origin | grep -E 'android-16\.0\.0_r' | head
```

如果还没 clone，可以直接对远端列：

```bash
git ls-remote --tags https://android.googlesource.com/platform/frameworks/base \
  | grep -E 'android-16\.0\.0_r' | head
```

你会看到类似：
- `refs/tags/android-16.0.0_r4`

### 9.2 在本地列出 tag

```bash
git tag | grep -E '^android-16\.0\.0_r' | sort -V
```

### 9.3 选择 rc4 的经验方法

- 若目标是“尽量对齐一个完整平台版本的某个发布点”，通常选最新的 `rN`（比如 r4）会比 r1/r2 更接近最终发布版本（bugfix 更多）。
- 但要注意：不同 repo 的 tag 覆盖范围不完全一致，存在“这个 tag 在 A 仓库有，在 B 仓库没有”的情况。
  - 解决办法：优先选择 **你真正依赖的仓库**（例如构建 build-tools 常用到的 frameworks/base / build system 相关）来确认 tag 是否存在。

### 9.4 checkout 指定 tag

```bash
git fetch --tags --force

git checkout android-16.0.0_r4
```

如果是 shallow clone 且没取到 tag：

```bash
git fetch --depth=1 origin tag android-16.0.0_r4

git checkout android-16.0.0_r4
```


## 10. get_source.py（AOSP/Android 16 rc4 拉取入口脚本）

为了让“从零复现”在新环境里更稳，我把本次实际使用的 `get_source.py` 一并归档到：

- `build-tools-36-aarch64/scripts/get_source.py`

校验（sha256）：
- `4b5c3b26798dbfe8da684a73f9d9aafcd0d51c922b254738445ec3e91275960f`

使用方式（示例）：
```bash
cd /root/workspace/build-tools-36-aarch64/scripts
python3 ./get_source.py --help

# 具体参数以脚本 help 输出为准；常见等价流程是：
# 1) repo init 指向正确 manifest
# 2) 选择/切换到 android-16.0.0_r4（rc4）相关 tag/分支
# 3) repo sync 拉齐源码
```

备注：如果你后续更新了脚本，务必同步更新这里的 sha256，并在 notes 里记录“更新原因”。

## 11. 一键复现（允许联网）交付说明

本目录已经包含“可联网复现”的最小交付集：

- `scripts/00_prereq.sh`：装依赖
- `scripts/10_fetch_sources.sh`：拉源码（android-sdk-tools + llvm-project）
- `scripts/20_build_lld.sh`：用 NDK 编 `lld/ld.lld`（当 NDK 自带 ld.lld 混架构/坏掉时）
- `scripts/30_patch_and_build_sdk_tools.sh`：打补丁并编译 android-sdk-tools
- `scripts/40_install_build_tools_36.sh`：安装/对齐到 SDK 的 `build-tools/36.0.0`
- `scripts/50_verify.sh`：基础验证

执行顺序详见：`scripts/README.md`

注意：这套脚本默认以“复现成功优先”，不会强行把所有仓库 pin 到固定 commit。
如果你希望长期可复现（CI/交付给别人），建议把每个仓库的 commit hash 写死到脚本里。

## 12. 面向 build-tools 37.0.0（未来升级）的应对方法（路线图）

当以后 AGP 强制 `build-tools >= 37`（或 Android 17/SDK 37）时，整体方法不变，变化点主要在：

### 12.1 先判断“为什么需要 37.0.0”
- **AGP 强制**：比如新版本 AGP 直接要求 37
- **compileSdk/targetSdk** 需要：构建链要求新 aapt2 行为
- **D8/R8/Apksigner** 版本要求：某些任务会检查工具版本

结论：通常仍然是 **aapt2 必须能跑通 link**，其它工具可以先从上一版 donor 复制，后续再对齐。

### 12.2 复用策略：先“最小可用”，再“对齐官方目录”
1) 先做出 `build-tools/37.0.0/aapt2`（aarch64 可执行且稳定）
2) 用 `36.0.0` 或 `35.0.1` 作为 donor 补齐：`apksigner/d8/lib/*.jar/NOTICE/runtime.properties/...`
3) 填 `source.properties`/`package.xml` 让 AGP 识别“已安装”
4) 用真实项目跑 `processResources + assembleRelease` 作为验收

### 12.3 可能会再次踩坑的点（提前准备）
- **liblog / bionic 行为变化**：Android API 更高时，日志符号/路径可能变，务必避免 fallback 递归
- **androidfw / AssetManager2**：AOSP 代码更新可能再次触发 libc++/C++20 的模板兼容问题
- **proto 格式**：AGP 的 aapt2-proto 版本可能变化，确保 aapt2 的 proto 读写兼容
- **NDK 工具链**：新 NDK 可能继续出现 host 工具混架构（尤其在 aarch64 Linux 上），要保留“自编 ld.lld / 修 wrapper”的能力

### 12.4 建议的升级流程（最省时间）
- 把本项目里的 `build-tools-36-aarch64/patches/*.patch` 复制一份为 `37` 分支
- 先尝试在新的 android-sdk-tools 版本上 `git apply`：
  - 能 apply：直接 build → 测试
  - 不能 apply：按报错点逐段迁移改动（建议从 liblog、androidfw、cmake source list 这三块开始）
- 每一次修复都要：
  - 用一个真实工程跑 `:app:processReleaseResources`（最先暴露 aapt2 link 问题）
  - 生成 core dump + gdb 定位（当 stderr 为空时）


## 13. 新机器一键准备 SDK/NDK（可联网）

如果你希望在“全新 Debian”上尽量少手工配置，可以用：

- `scripts/05_fetch_ndk_sdk.sh`

它会：
- 下载并安装 Android `cmdline-tools`（sdkmanager）到 `$ANDROID_SDK_ROOT/cmdline-tools/latest`
- 用 sdkmanager 安装：
  - `platform-tools`
  - `build-tools;35.0.1`（作为 donor）
  - `platforms;android-36`（可按需改）
  - `ndk;29.0.14206865`（我们当时使用的版本）

用法：
```bash
export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
./scripts/05_fetch_ndk_sdk.sh
export ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
```

备注：sdkmanager 的下载源在某些网络环境下可能较慢/失败，可自行配置代理或替换镜像源。
