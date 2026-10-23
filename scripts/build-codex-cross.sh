#!/bin/bash
# Cross-build OpenAI Codex CLI for old-world LoongArch (ABI1.0 / glibc 2.28)
# on an x86_64 host. See docs/CODEX-BUILD.md (CROSS success section).
set -euo pipefail

X=${CROSS_ROOT:-/workspace/cross}
T=$X/loongson-gnu-toolchain-8.3-x86_64-loongarch64-linux-gnu-rc1.6
SRC=${CODEX_SRC:-/workspace/kylin-vm-test2/hostcache/codex/codex-rs}
JOBS=${JOBS:-2}

export PATH=$X/rust/bin:$T/bin:$PATH

# Host build.rs / proc-macros: Rust 1.99 defaults to rust-lld which may SIGSEGV
# on some Debian hosts. Force GNU ld.bfd by wrapping cc.
WRAP=$X/hostbin
mkdir -p "$WRAP"
cat > "$WRAP/cc" << 'W'
#!/bin/bash
args=()
for a in "$@"; do
  case "$a" in
    -fuse-ld=lld|-fuse-ld=mold) ;;
    *) args+=("$a") ;;
  esac
done
exec /usr/bin/cc "${args[@]}"
W
cat > "$WRAP/c++" << 'W'
#!/bin/bash
args=()
for a in "$@"; do
  case "$a" in
    -fuse-ld=lld|-fuse-ld=mold) ;;
    *) args+=("$a") ;;
  esac
done
exec /usr/bin/c++ "${args[@]}"
W
chmod +x "$WRAP/cc" "$WRAP/c++"
export PATH=$WRAP:$PATH
export CC=$WRAP/cc CXX=$WRAP/c++

export CARGO_TARGET_LOONGARCH64_UNKNOWN_LINUX_GNU_LINKER=loongarch64-linux-gnu-gcc
export CC_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-gcc
export CXX_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-g++
export AR_loongarch64_unknown_linux_gnu=loongarch64-linux-gnu-ar

# Large binary: default code model truncates PC-relative relocs (aws-lc-sys -> memcpy).
# Loongson gcc 8.3 accepts tiny/normal/large/extreme (not "medium").
export CFLAGS_loongarch64_unknown_linux_gnu="${CFLAGS_loongarch64_unknown_linux_gnu:--mcmodel=large -O2}"
export CXXFLAGS_loongarch64_unknown_linux_gnu="${CXXFLAGS_loongarch64_unknown_linux_gnu:--mcmodel=large -O2}"
export RUSTFLAGS="${RUSTFLAGS:-} -C code-model=large -C link-arg=-Wl,--no-keep-memory"

export OPENSSL_DIR=$X/ossl/usr
export OPENSSL_LIB_DIR=$X/ossl/usr/lib/loongarch64-linux-gnu
export OPENSSL_INCLUDE_DIR=$X/ossl/usr/include

export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_INCREMENTAL=0
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$X/target}

cd "$SRC"
rm -f rust-toolchain.toml rust-toolchain
date
time cargo build --offline --release -p codex-cli --bin codex \
  --target loongarch64-unknown-linux-gnu -j "$JOBS"
BIN=$CARGO_TARGET_DIR/loongarch64-unknown-linux-gnu/release/codex
loongarch64-linux-gnu-strip "$BIN" || true
ls -lh "$BIN"
file "$BIN"
readelf -l "$BIN" | grep -A2 INTERP || true
echo CROSS_DONE
