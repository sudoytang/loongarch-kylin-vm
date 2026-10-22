#!/bin/bash
# Host side: download Loongnix ABI1.0 Rust + Codex source, vendor crates, and extract the libc dev debs.
# Output goes to ./hostcache; serve with `python3 -m http.server 8000` from the repo root, and the guest uses
# CACHE_URL=http://10.0.2.2:8000/hostcache guest/build-codex.sh
# Needs a host cargo (rustup) for `cargo vendor`, plus bsdtar, curl.
set -e
cd "$(dirname "$0")/.."
TAG=${CODEX_TAG:-rust-v0.163.0}; RV=${RUST_VER:-1.99.0}; RD=${RUST_DATE:-2026-10-09}
mkdir -p hostcache; cd hostcache
T=rust-$RV-loongarch64-unknown-linux-gnu.tar.xz
until curl -fL -C - --speed-limit 20000 --speed-time 20 -o $T https://ftp.loongnix.cn/toolchain/rust/rust-${RV%.*}/$RD/abi1.0/$T; do sleep 2; done
curl -fsL https://ftp.loongnix.cn/toolchain/rust/rust-${RV%.*}/$RD/abi1.0/$T.sha256 | awk '{print $1"  '$T'"}' | sha256sum -c -
curl -fL https://github.com/openai/codex/archive/refs/tags/$TAG.tar.gz -o codex-$TAG.tar.gz
rm -rf codex && mkdir codex && tar xzf codex-$TAG.tar.gz -C codex --strip-components=1
( cd codex/codex-rs && rm -f rust-toolchain.toml && mkdir -p .cargo && cargo vendor vendor > .cargo/config.toml )
tar czf codex-$TAG-vendored.tar.gz codex && rm -rf codex
# C dev files missing from the installed image (exact match to installed libc6 is on the ISO)
ISO=../Kylin-2503-loongarch64.iso
for p in libc6-dev libc-dev-bin; do bsdtar -xOf $ISO pool/main/g/glibc/${p}_2.28-10.kylin.35k1.0_loongarch64.deb > ${p}_2.28-10.kylin.35k1.0_loongarch64.deb; done
curl -fLO https://pkg.loongnix.cn/loongnix/pool/main/l/linux/linux-libc-dev_4.19.190.8.29-lnd.14_loongarch64.deb
ls -la
