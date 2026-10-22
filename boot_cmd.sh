#!/bin/bash
# Boot the installer ISO (live session) and pass custom kernel args via the GRUB command line
# over serial. (Editing the GRUB menu entry over serial does not take effect.)
# Usage: ./boot_cmd.sh ["kernel args"]
cd "$(dirname "$0")"
ARGS=${1:-"boot=casper audit=0 locale=zh_CN fsck.mode=skip security= console=ttyS0,115200 loglevel=7 initcall_blacklist=nct6102_gpio_setup,loongson_ls7a_hwmon_init modprobe.blacklist=parport_pc,it87"}
echo quit | socat - UNIX-CONNECT:mon.sock >/dev/null 2>&1; sleep 2; : > serial.log
setsid nohup ./run.sh install > qemu.log 2>&1 < /dev/null &
for i in $(seq 300); do grep -aq 'executed automatically' serial.log && break; sleep 1; done
S(){ printf '%s' "$1" | socat - UNIX-CONNECT:serial.sock; sleep 1; }
S 'c'; sleep 2
S "linux /casper/vmlinuz $ARGS"; S $'\r'; sleep 60
S 'initrd /casper/initrd.img'; S $'\r'
for i in $(seq 900); do tail -c 200 serial.log | grep -aq 'grub> *$' && break; sleep 2; done
S 'boot'; S $'\r'; echo booted
