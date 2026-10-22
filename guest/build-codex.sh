#!/bin/bash
# Build OpenAI Codex CLI natively inside the old-world (ABI1.0) Kylin VM.
# Run as the normal user (kylin). Resumable: re-run to continue.
#   CODEX_TAG   git tag to build (default rust-v0.163.0)
#   RUST_VER    Loongnix ABI1.0 rust version (default 1.99.0, dated dir 2026-10-09)
set -ex
CODEX_TAG=${CODEX_TAG:-rust-v0.163.0}
RUST_VER=${RUST_VER:-1.99.0}
RUST_DATE=${RUST_DATE:-2026-10-09}
W=$HOME/codex-build; mkdir -p $W; cd $W

# 1. swap (codex link step needs lots of RAM). Needs sudo: create it beforehand interactively
#    if sudo cannot prompt (setsid/nohup).
if ! swapon --show | grep -q /swapfile; then
  [ -f /swapfile ] || { sudo fallocate -l 8G /swapfile; sudo chmod 600 /swapfile; sudo mkswap /swapfile; }
  sudo swapon /swapfile
fi

# 2. Rust (Loongnix ABI1.0 build) into ~/.local/rust
if [ ! -x $HOME/.local/rust/bin/cargo ]; then
  T=rust-$RUST_VER-loongarch64-unknown-linux-gnu
  curl -fLO ${CACHE_URL:+$CACHE_URL/}$T.tar.xz 2>/dev/null || curl -fLO https://ftp.loongnix.cn/toolchain/rust/rust-${RUST_VER%.*}/$RUST_DATE/abi1.0/$T.tar.xz
  tar xf $T.tar.xz && ./$T/install.sh --prefix=$HOME/.local/rust --disable-ldconfig
  rm -rf $T $T.tar.xz
fi
export PATH=$HOME/.local/rust/bin:$PATH
rustc -vV; cargo -V

# 3. source
# Preferred: host-prepared tarball with `cargo vendor` output + .cargo/config.toml
# (scripts/prepare-codex-src.sh); guest TLS downloads under TCG are ~200 KB/s.
if [ ! -d codex ]; then
  if [ -n "$CACHE_URL" ]; then
    curl -fL $CACHE_URL/codex-$CODEX_TAG-vendored.tar.gz | tar xz
  else
    curl -fL https://github.com/openai/codex/archive/refs/tags/$CODEX_TAG.tar.gz | tar xz
    mv codex-$CODEX_TAG codex
  fi
fi
cd codex/codex-rs
rm -f rust-toolchain.toml rust-toolchain   # use the installed toolchain, not rustup channel

# 4. build (thin/no LTO, more codegen units: less RAM/time under emulation)
export CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 CARGO_INCREMENTAL=0
export CARGO_NET_GIT_FETCH_WITH_CLI=false
cargo build ${CACHE_URL:+--offline} --release -p codex-cli --bin codex -j ${JOBS:-4} 2>&1 | tee -a $W/build.log
ls -la target/release/codex && ./target/release/codex --version
echo CODEX_BUILD_DONE
