# Galaxy Kylin Desktop V10 SP1 (LoongArch64) on an emulated Loongson 3A6000

This repo has the scripts and notes for running **Galaxy Kylin Desktop OS V10 SP1 2503 (银河麒麟桌面操作系统 V10 SP1, LoongArch64 build)** on an x86_64 Linux host.
The VM uses QEMU's `virt` machine with the `la464` CPU, the core used in the Loongson 3A5000/3A6000. It is full-system emulation (TCG), with no KVM.

Status: **working.** The installed system boots to the UKUI graphical login screen (`docs/installed-desktop.png`) and to a serial getty. With 4 vCPUs it reaches login in about 45 s.
Proof of the installed system (uname, old-world `ld.so.1`, os-release): `docs/verify.txt`.

![login screen](docs/installed-desktop.png)

## Key facts
- **ISO:** `Kylin-Desktop-V10-SP1-2503-Release-20250430-LoongArch64.iso` from Kylin's official CDN. No registration is needed. MD5 `e92d0f4256c0734f970cabe7b19f0067`.
- **ABI:** the ISO is **old-world (ABI 1.0)**. It uses kernel `5.4.18-142-generic` (an ELF image loaded by the old-world GRUB), glibc 2.28 and `/lib64/ld.so.1`. Software built for new-world (ABI 2.0) will not run on it unmodified.
- **Firmware:** it still boots with **new-world EDK2 firmware** on stock QEMU, with no old-world "BPI" firmware needed. When the firmware provides no BPI table, the old-world GRUB hands the UEFI system table to the kernel.
- **Host used:** Debian 13 with QEMU 10.0.13 (`qemu-system-misc`).

## Requirements
- Linux x86_64 host with `qemu-system-loongarch64` (QEMU ≥ 9; tested with 10.0.13) and `qemu-img`.
- `socat` and `python3` (serial/monitor helpers). `imagemagick` is needed for `shot.sh`.
- About 80 GB of disk (4.3 GB ISO plus a 64 GB sparse qcow2; about 10 GB is used after install) and 4+ GB of RAM.

```bash
sudo apt install qemu-system-misc qemu-utils socat python3 imagemagick
```

## Quickstart
```bash
scripts/fetch-iso.sh        # download the official ISO and check its MD5
scripts/build-disk.sh       # unattended headless install into kylin.qcow2 (~17 min with SMP=4)
./run.sh                    # boot the installed system
```
Then:
- **GUI:** VNC to `127.0.0.1:5901` (bound to localhost; tunnel with `ssh -L 5901:127.0.0.1:5901 host` if needed).
- **Serial console:** `socat -,raw,echo=0 UNIX-CONNECT:serial.sock`. Everything is also logged to `serial.log`.
- **QEMU monitor:** `socat - UNIX-CONNECT:mon.sock`.
- **Screenshot:** `./shot.sh name` writes `name.png` (monitor `screendump`).

`run.sh` settings, all set through environment variables:

| Variable | Default |
|---|---|
| `FW` | `fw/debian-edk2-QEMU_EFI.fd` |
| `SMP` | `4` |
| `MEM` | `4G` |
| `DISK` | `kylin.qcow2` |
| `ISO` | `Kylin-2503-loongarch64.iso` |
| `QEMU` | `qemu-system-loongarch64` |
| `EXTRA` | extra QEMU arguments (e.g. `-d int -D /tmp/int.log`) |

`./run.sh install` also attaches the ISO.

## Credentials
`scripts/build-disk.sh` and `guest/install.sh` set the same password for users `kylin` (sudo) and `root` from the required `VM_PASSWORD` environment variable (no default).
Pick a strong password for the lab VM (`VM_PASSWORD='…' scripts/build-disk.sh`), and change it with `passwd` in the guest if the VM is reachable by others.
In the live ISO session, user `kylin` has no password.

Serial login quirk: Kylin prints `Input Password` only after a delay, and anything typed before that prompt is lost. Type the user name, wait for the prompt, then type the password. `./sertype.py "text" [wait_s]` types slowly over the serial socket.

## How the install works (manual steps)
The graphical installer (ubiquity) is not used. Instead:
1. `./boot_cmd.sh` boots the ISO and types a custom kernel command line at the GRUB `c` prompt over serial (see blacklists below). Editing the menu entry over serial did *not* take effect.
2. Log in on serial as `kylin` (no password).
3. Run `guest/install.sh` as root. The host serves it over HTTP and the guest fetches it from `10.0.2.2`. It:
   - creates GPT `vda1` (ESP, 512 MiB, FAT32) and `vda2` (ext4);
   - copies the live root (`cp -a /rofs/. /mnt`, about 20 min);
   - writes fstab and the hostname;
   - purges ubiquity/casper;
   - sets passwords with `usermod -p <sha512 hash>` (Kylin's PAM password-quality rules reject `chpasswd`);
   - puts the blacklists in `/etc/default/grub`;
   - runs `update-initramfs`, `grub-install --removable` and `update-grub`.
4. Power off. `./run.sh` then boots the disk.

`scripts/build-disk.sh` automates steps 1–4.

## Required kernel command line
QEMU `virt` lacks some Loongson board hardware that Kylin's kernel probes without checking first:

| Parameter | Why |
|---|---|
| `initcall_blacklist=nct6102_gpio_setup` | Panics. It reads a Super-I/O GPIO (`read_gbl`) that doesn't exist on `virt` (address error). |
| `initcall_blacklist=loongson_ls7a_hwmon_init` | Panics. It reads LS7A bridge hwmon registers QEMU doesn't emulate. |
| `modprobe.blacklist=parport_pc,it87` | Non-fatal oopses from probes of legacy ISA/Super-I/O ports (`superio_enter` in `it87`). |
| `console=ttyS0,115200` | Serial console. The ISO's default cmdline is `quiet splash loglevel=0`. |

`guest/install.sh` writes these into GRUB on the installed disk.

## SMP / firmware investigation
**Symptom:** with the older firmware `fw/9b8f2a0_…` and `-smp 2` or more, the kernel logs `Booting CPU#1...` and, 5 s later, `CPU1: failed to start`, then `smp: Brought up 1 node, 1 CPU`.

**Mechanism.** I disassembled the firmware's secondary-CPU park loop from the `.fd` at `0x1c002000` (objdump from `binutils-loongarch64-linux-gnu`). It:
1. sets EENTRY to `0x1c003000`;
2. clears mailbox0 (IOCSR `0x1020`) and enables IPI (ECFG.IPI, IOCSR `0x1004`);
3. runs `idle 0`;
4. polls `iocsrrd.w 0x1020` until it is non-zero, then clears the IPI (`0x100c`);
5. loads `iocsrrd.d 0x1020` and `jr`s to it in DA mode with no DMW set.

The old-world kernel's `boot_secondary` writes the entry point into that mailbox and sends an IPI. That part works: CPU1 does wake up.

**Root cause:** the firmware's own flash becomes unreadable.
- QEMU's `-d int` log for cpu 1 at wake-up shows:
  ```
  Error: unknown opcode. 0x1c002068: 0xffffffff
  loongarch_cpu_do_interrupt enter: pc 000000001c002068 ... exception: 13 (Instruction Non-Existent)
  loongarch_cpu_do_interrupt: PC 000000001c003000 ERA 000000001c002068 cause 13
  ```
- `0x1c000000–0x1cffffff` is QEMU 10's `virt.flash0` (a pflash device in romd mode).
- With `-S` (CPU paused at reset), `xp/4wx 0x1c002064` returns the real code (`06488000 03400000 064809ac 43fff59f`).
- About 3 s after the 2023 firmware starts, the same read returns `0xffffffff`. The firmware seems to take flash0 out of read-array mode, presumably by sending flash commands meant for the flash layout of the QEMU version it was built for. This is inferred from the behaviour; I didn't confirm it in the firmware source.
- The parked CPU only survives as long as it sits in `idle` on already-translated code. Once woken it refetches from flash, gets `0xffffffff`, takes an INE exception, and EENTRY (also in flash) faults again in an endless loop.
- The monitor confirms the final state: `cpu 1` sits at PC=ERA=EENTRY=`0x1c003000`, CRMD=`0x8` (DA), DMW0-3=0, ESTAT=`0xd1000`.

**Fix:** use newer firmware. With `fw/debian-edk2-QEMU_EFI.fd` (EDK2 2025.02) or `fw/638906d_QEMU_EFI.fd`, flash0 stays readable after boot and all CPUs come up (`smp: Brought up 1 node, 4 CPUs`, `nproc` = 4). The old-world kernel boots normally on this new-world firmware, and boot to login drops from about 3–4 min (`-smp 1`) to about 45 s (`-smp 4`).
No kernel or QEMU change is needed. The QEMU IPI/mailbox semantics match what the old-world kernel expects.

Other notes:
- QEMU 7.2.15 (built from source for the 2022 firmware) did not help. The 1f097fe firmware panics there with no BPI and hangs on QEMU 10.
- Building QEMU 7.2 on Python 3.13 needs a venv with `setuptools` (`--python=/abs/path/venv/bin/python3`), because distutils is gone.

## Known issues
- **No SSH server:** openssh-server is not in the image (`ssh.service` does not exist). Port 10022 is forwarded; install `openssh-server` in the guest (needs repos or a .deb) to use it.
- **`it87` oops:** this repo's `guest/install.sh` blacklists `it87`, but disks built with the earliest version only blacklist `parport_pc`. The oops is harmless.
- **Kylin activation:** Kylin shows activation/trial notices (the ISO's `.kyinfo` term ends 2026-07-29). It is not needed to boot or log in.
- **No sound card:** pulseaudio warns `no soundcards found`; no audio device is emulated.
- **Speed:** TCG emulation is slow for heavy GUI use. Expect a sluggish desktop.
- **Guest clock:** the guest shows UTC (14:52 on the screenshot = 22:52 UTC+8).

## Files
| Path | Purpose |
|---|---|
| `run.sh` | Start the VM |
| `boot_cmd.sh` | Boot the ISO with a custom kernel cmdline via the GRUB prompt |
| `scripts/fetch-iso.sh` | Download and verify the ISO |
| `scripts/build-disk.sh` | Automated headless install |
| `guest/install.sh` | In-guest installer |
| `shot.sh` | Monitor screendump to PNG |
| `typekeys.py` | Type through the monitor `sendkey` (for the VGA console) |
| `sertype.py` | Type slowly on the serial socket |
| `fw/` | EDK2 firmware builds (see `fw/README.md` for sources and licenses) |
| `docs/verify.txt` | Proof output from the installed guest |
| `docs/installed-desktop.png` | Login screen screenshot |
| `logs/boot-smp4-debian-fw.log` | Trimmed serial boot log with `-smp 4` |

## OpenAI Codex CLI (old-world LoongArch binary)
A cross-built `codex` for this ABI1.0 / glibc 2.28 image lives in `artifacts/codex` after a successful build (see `docs/CODEX-BUILD.md`). Config example for DeepSeek / OpenAI-compatible backends: `docs/CODEX-CONFIG.md`.
