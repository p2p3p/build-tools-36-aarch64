#!/usr/bin/env bash
set -euo pipefail

# Install build prerequisites for Debian bookworm.
# Safe to run multiple times.

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y \
  git ca-certificates curl wget unzip zip xz-utils file \
  python3 python3-venv python3-pip \
  cmake ninja-build pkg-config \
  build-essential \
  bison flex \
  libssl-dev zlib1g-dev \
  gdb

echo "[OK] prerequisites installed"
