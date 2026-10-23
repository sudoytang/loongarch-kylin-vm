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

## Status 2026-10-22 22:10 (UTC+8)
- Build runs detached in the guest (`setsid` bash ~/build-codex.sh, PPID 1, no tty), so it survives the serial session / host task ending. Log: `~/codex-build/build.log` (top errors lines 1-46 are from the earlier run before the libc6-dev fix; ignore). `CODEX_BUILD_DONE` is printed to `~/build-codex.out` at the end.
- 280 of ~1033 units compiled after ~65 min (4 jobs, TCG). openssl-sys 0.9.111, ring 0.17.14 and aws-lc-sys 0.45.0 build scripts all passed (hyper-tls, aws-lc-rs compile after them). No new errors.
- ETA: several hours more; the large codex-* crates come last and are slowest.
- Check: `./sertype.py 'clear; grep -c Compiling ~/codex-build/build.log; tail -2 ~/codex-build/build.log; tail -3 ~/build-codex.out' 10; tail -c 600 serial.log`

## CROSS: x86_64 host -> old-world loongarch64 (ABI1.0)
Toolchains (both exist, official Loongnix):
- Rust: https://rust-lang.loongnix.cn/dist/1.99.0/2026-10-09/ has `rust-1.99.0-x86_64-unknown-linux-gnu.tar.xz` (rustc 1.99.0 a4d5d3f0e, same commit as the native guest rustc, LLVM 22.1.8) and `rust-std-1.99.0-loongarch64-unknown-linux-gnu.tar.xz`. Install both with `install.sh --prefix=/workspace/cross/rust`. (No .sha256 files are published there; they return 404.) The Loongnix builder-config shows the native toolchain itself was cross-built this way with `loongarch64-linux-gnu-gcc`.
- GCC: https://ftp.loongnix.cn/toolchain/gcc/release/loongarch/gcc8/loongson-gnu-toolchain-8.3-x86_64-loongarch64-linux-gnu-rc1.6.tar.xz (md5 OK). It ships binutils 2.31.1, gcc 8.3.0, glibc 2.28 and a full sysroot, so no guest sysroot is needed.
- OpenSSL: extract libssl-dev + libssl1.1 1.1.1d-0+lnd.13 debs (pkg.loongnix.cn) into `/workspace/cross/ossl`, copy `usr/include/loongarch64-linux-gnu/openssl/*` into `usr/include/openssl/`, and set OPENSSL_DIR/LIB_DIR/INCLUDE_DIR.
- aws-lc-sys 0.45, ring and openssl-sys build scripts all succeed with only CC/CXX/AR_loongarch64_unknown_linux_gnu set; no cmake is needed on the host.
- Script: `scripts/build-codex-cross.sh` (uses the vendored tree in hostcache/codex/codex-rs, target dir /workspace/cross/target). Run it detached: `JOBS=4 setsid nohup ./build-cross.sh > cross.log 2>&1 &`
- Timing: 486 units in about 11 min with 4 jobs (the host is shared with the running TCG VM).
- INCIDENT: the host has 16 GB RAM and no swap. Running the cross build with -j4 next to the 7G TCG VM made the host OOM killer kill qemu at 2026-10-22 23:57 (UTC+8), which stopped the in-guest native build. The guest target dir is on the qcow2, so a rerun of build-codex.sh resumes it. Later, rustc for codex_core (about 4 GB RSS) was OOM-killed too. Rule: never run the cross build and the VM at the same time, or use JOBS<=2 with a smaller VM MEM. The cross build was restarted with JOBS=2 at 00:35 (UTC+8) and the log is /workspace/cross/cross2.log.

## CROSS success (2026-10-24, Debian build host)

Built on an x86_64 Debian 13 machine, not under TCG.
Result binary: `artifacts/codex` (also saved as `~/cross/codex-loongarch64` on the build host).

Verified:
- ELF LoongArch 64-bit LSB pie, stripped
- interpreter `/lib64/ld.so.1` (old-world)
- max GLIBC symbol `GLIBC_2.28` (matches Kylin V10 SP1)

### Host setup that worked
- Rust 1.99.0 from Loongnix: `rust-1.99.0-x86_64-unknown-linux-gnu` + `rust-std-1.99.0-loongarch64-unknown-linux-gnu`
- GCC: `loongson-gnu-toolchain-8.3-x86_64-loongarch64-linux-gnu-rc1.6` (glibc 2.28 sysroot)
- OpenSSL headers: libssl-dev 1.1.1d unpacked to `ossl/`
- Codex source: tag `rust-v0.163.0`; delete `rust-toolchain.toml` (wants 1.99.1; Loongnix has 1.99.0)
- RAM: ~7 GB + ~23 GB swap; build with `-j2`, `CARGO_PROFILE_RELEASE_DEBUG=0`, LTO off, codegen-units 16
- Mainland China network: GitHub git deps stall easily. Prefer `cargo vendor` elsewhere and `--offline`, or China crates mirrors (`rsproxy.cn` / USTC).

### Two gotchas fixed during the successful run
1. **Host `rust-lld` SIGSEGV.** Cross builds still compile host `build.rs` / proc-macros. Rust 1.99 defaults to `-fuse-ld=lld` (bundled `rust-lld`), which segfaulted on this Debian host. Workaround: wrap `cc`/`c++` to drop `-fuse-ld=lld` and force GNU `ld.bfd` (see `scripts/build-codex-cross.sh`).
2. **Final link `relocation truncated to fit`** against `memcpy` inside `aws-lc-sys`. The release binary is too large for the default small/normal code model. Loongson gcc 8.3 does **not** accept `-mcmodel=medium` (only `tiny`/`normal`/`large`/`extreme`). Fix: `export CFLAGS_loongarch64_unknown_linux_gnu='-mcmodel=large'` (and matching `RUSTFLAGS` `--codegen code-model=large` / target linker flags). Rebuild `ring` / `aws-lc-sys` after changing the model; a plain relink is not enough.

Smoke in the Kylin VM (this repo's `kylin.qcow2`): `codex --version` and a no-API-key launch with `--dangerously-bypass-approvals-and-sandbox`. See `docs/CODEX-CONFIG.md` for a DeepSeek / OpenAI-compatible `~/.codex/config.toml` example.
