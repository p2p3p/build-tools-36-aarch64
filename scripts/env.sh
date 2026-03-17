#!/usr/bin/env bash
set -euo pipefail

# Centralized version pins / defaults for this repo.

# Donor build-tools version (installed via sdkmanager)
export DONOR_BUILD_TOOLS_VERSION="35.0.1"

# NDK version used for the successful build
export NDK_VERSION="29.0.14206865"

# Android platform (optional, only needed if you want platform installed)
export ANDROID_PLATFORM="android-36"

# cmdline-tools package zip (linux)
export CMDLINE_TOOLS_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
