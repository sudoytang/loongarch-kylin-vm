# Firmware

All files are EDK2 (TianoCore) UEFI builds for the QEMU LoongArch `virt` machine.
EDK2 is licensed **BSD-2-Clause-Patent** (https://github.com/tianocore/edk2/blob/master/License.txt).
They are redistributed unmodified.

| File | Source | SHA-256 | Notes |
|---|---|---|---|
| `debian-edk2-QEMU_EFI.fd` | Debian trixie package `qemu-efi-loongarch64` 2025.02-8+deb13u1 (`/usr/share/qemu-efi-loongarch64/QEMU_EFI.fd`) | 572759ad…54fee2cd | **Default.** Boots the old-world Kylin kernel; SMP works. |
| `638906d_QEMU_EFI.fd` | github.com/loongson/Firmware @ 638906de (2024-07, `LoongArchVirtMachine/QEMU_EFI.fd`) | ee61040d…4fe5f588 | SMP works (CPU1 brought up); full boot not tested. |
| `9b8f2a0_edk2-loongarch64-code.fd` | github.com/loongson/Firmware @ 9b8f2a03 (2023-06) | 71d329de…c1367037 | First firmware found to boot Kylin. **SMP broken** on QEMU 10 (see main README). |
| `1f097fe_edk2-loongarch64-code.fd` | github.com/loongson/Firmware @ 1f097fef (2022-11, first release) | 7ddda86d…b668d0179 | Hangs on QEMU 10; panics on QEMU 7.2. Kept for reference. |
