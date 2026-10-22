#!/bin/bash
# Boot the Galaxy Kylin Desktop V10 SP1 (LoongArch64) VM on QEMU virt / la464.
#   ./run.sh            boot installed disk (kylin.qcow2)
#   ./run.sh install    also attach the installer ISO (boots it first)
# VNC 127.0.0.1:5901 | monitor ./mon.sock | serial ./serial.sock (log ./serial.log) | ssh fwd host:10022
# Env: FW, SMP (default 4), MEM (default 4G), QEMU, DISK, ISO, EXTRA (extra qemu args)
cd "$(dirname "$0")"
FW=${FW:-fw/debian-edk2-QEMU_EFI.fd}
DISK=${DISK:-kylin.qcow2}
ISO=${ISO:-Kylin-2503-loongarch64.iso}
CD=()
[ "$1" = install ] && CD=(-drive if=none,id=cd,media=cdrom,readonly=on,file="$ISO" -device virtio-scsi-pci,id=scsi -device scsi-cd,drive=cd,bootindex=0)
exec ${QEMU:-qemu-system-loongarch64} $EXTRA -M virt -cpu la464 -smp ${SMP:-4} -m ${MEM:-4G} \
  -accel tcg,thread=multi -bios "$FW" \
  -drive if=none,id=hd,file="$DISK",format=qcow2,cache=unsafe -device virtio-blk-pci,drive=hd,bootindex=1 \
  "${CD[@]}" \
  -device virtio-gpu-pci -device nec-usb-xhci,id=xhci -device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0 \
  -netdev user,id=n0,hostfwd=tcp::10022-:22 -device virtio-net-pci,netdev=n0 \
  -display none -vnc 127.0.0.1:1 -monitor unix:mon.sock,server,nowait \
  -chardev socket,id=ser0,path=serial.sock,server=on,wait=off,logfile=serial.log,logappend=on -serial chardev:ser0
