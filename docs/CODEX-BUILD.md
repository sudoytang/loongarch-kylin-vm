# Building OpenAI Codex CLI natively in the old-world Kylin VM (work log)

Target: `codex` (codex-rs) built natively inside Kylin V10 SP1 2503 LoongArch64, old-world ABI1.0 (glibc 2.28, kernel 5.4.18).

## Setup that worked so far
- VM: `MEM=7G ./run.sh` (4 vCPU, Debian fw) plus an 8 GiB guest swapfile (`/swapfile`, created interactively because sudo needs a tty).
- Rust: Loongnix ABI1.0 build **rust 1.99.0** (`rust-1.99.0-loongarch64-unknown-linux-gnu.tar.xz`, https://ftp.loongnix.cn/toolchain/rust/rust-1.99/2026-10-09/abi1.0/, sha256 127a4130…). Installed with `install.sh --prefix=$HOME/.local/rust`.
- Codex wants `channel = "1.99.1"` (rust-toolchain.toml). Loongnix has 1.99.0, so we delete rust-toolchain.toml and use 1.99.0.
- Codex source: tag **rust-v0.163.0** (latest release, 2026-10-15). Fetching inside the guest is slow (TLS under TCG runs at ~200 KB/s and stalls), so the host does `cargo vendor` (1.8 GB, 300 MB tgz) and the guest builds with `--offline`. See `scripts/prepare-codex-src.sh`.
- Build: `guest/build-codex.sh`, which uses `CARGO_PROFILE_RELEASE_LTO=false`, `CODEGEN_UNITS=16` and `-j4`.

## Problems hit
1. The image has no C dev files (`cannot find Scrt1.o / crti.o`). The guest's apt source points to an unreachable internal build proxy, and public Kylin repos were unreachable from here. Fix: `libc6-dev` + `libc-dev-bin` 2.28-10.kylin.35k1.0 from the ISO pool (an exact match for the installed libc6), plus `linux-libc-dev` 4.19.190.8.29-lnd.14 from the Loongnix 20 repo (pkg.loongnix.cn DaoXiangHu-stable). Installed with `dpkg -i`.

## Problem 2: openssl-sys / aws-lc-sys build deps (pre-empted)
`cargo tree --target loongarch64-unknown-linux-gnu -p codex-cli` shows openssl-sys (via native-tls), aws-lc-sys (cmake build-dep) and ring. Guest had perl+make but no libssl-dev, pkg-config, or cmake, and the apt mirror is unreachable.
Installed from pkg.loongnix.cn DaoXiangHu-stable via `dpkg -i --force-depends` (served from hostcache/):
- libssl-dev 1.1.1d-0+lnd.13 (guest runtime is libssl1.1 1.1.1f-1kylin2.23k0.4; same 1.1.1 ABI, so --force-depends is safe for headers + libssl.so symlink)
- pkg-config 0.29-6.1
- cmake 3.13.4-1.lnd.2, cmake-data, librhash0 1.3.8 (other cmake deps already present)
