#!/bin/bash
# Cross-build codex for old-world LoongArch (ABI1.0) on x86_64 host
set -e
X=/workspace/cross
T=$X/loongson-gnu-toolchain-8.3-x86_64-loongarch64-linux-gnu-rc1.6
export PATH=$X/rust/bin:$T/bin:$PATH
export CARGO_TARGET_LOONGARCH64_UNKNOWN_LINUX_GNU_LINKER=loongarch64-linux-gnu-gcc
export CC_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-gcc
export CXX_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-g++
export AR_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-ar
export OPENSSL_DIR=$X/ossl/usr OPENSSL_LIB_DIR=$X/ossl/usr/lib/loongarch64-linux-gnu OPENSSL_INCLUDE_DIR=$X/ossl/usr/include
export CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 CARGO_INCREMENTAL=0
export CARGO_TARGET_DIR=$X/target
cd /workspace/kylin-vm-test2/hostcache/codex/codex-rs
date; time cargo build --offline --release -p codex-cli --bin codex --target loongarch64-unknown-linux-gnu -j ${JOBS:-$(nproc)}
echo CROSS_DONE
