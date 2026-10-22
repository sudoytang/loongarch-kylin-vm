#!/bin/bash
# Headless install of the Kylin live system onto /dev/vda.
# Run as root inside the live session booted with boot_cmd.sh (see README).
# WARNING: wipes /dev/vda.
#   VM_PASSWORD  required; password set for users kylin and root
#   TARGET_DISK  target disk (default: /dev/vda)
set -ex
D=${TARGET_DISK:-/dev/vda}
PW=${VM_PASSWORD:?set VM_PASSWORD before running}
BL="console=tty0 console=ttyS0,115200 initcall_blacklist=nct6102_gpio_setup,loongson_ls7a_hwmon_init modprobe.blacklist=parport_pc,it87"
KVER=$(uname -r)

parted -s $D mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 esp on mkpart root ext4 513MiB 100%
sleep 2
mkfs.vfat -F32 ${D}1
mkfs.ext4 -F -q ${D}2
mount ${D}2 /mnt
echo "copying rootfs (slow under TCG, ~20 min)"
cp -a /rofs/. /mnt/
mkdir -p /mnt/boot/efi
mount ${D}1 /mnt/boot/efi
for f in dev dev/pts proc sys sys/firmware/efi/efivars run; do
  mkdir -p /mnt/$f; mount --bind /$f /mnt/$f || true
done

U1=$(blkid -s UUID -o value ${D}2); U2=$(blkid -s UUID -o value ${D}1)
printf "UUID=$U1 / ext4 errors=remount-ro 0 1\nUUID=$U2 /boot/efi vfat umask=0077 0 1\n" > /mnt/etc/fstab
echo kylin-vm > /mnt/etc/hostname
[ -e /mnt/boot/vmlinuz-$KVER ] || cp /cdrom/casper/vmlinuz /mnt/boot/vmlinuz-$KVER

# chpasswd is rejected by Kylin's PAM password-quality rules, so set crypt hashes directly
HASH=$(python3 -c "import crypt,sys; print(crypt.crypt(sys.argv[1], crypt.METHOD_SHA512))" "$PW")
REMOVE="$(awk '{print $1}' /cdrom/casper/filesystem.manifest-remove 2>/dev/null) casper lupin-casper"

chroot /mnt /bin/bash -ex <<CH
for p in $REMOVE; do dpkg -P --force-depends \$p || true; done
id kylin || useradd -m -s /bin/bash -G sudo,adm kylin
usermod -p '$HASH' kylin
usermod -p '$HASH' root
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="$BL"|' /etc/default/grub
grep -q GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT="$BL"' >> /etc/default/grub
update-initramfs -c -k $KVER || update-initramfs -u -k all
grub-install --target=loongarch64-efi --efi-directory=/boot/efi --removable --no-nvram || grub-install --efi-directory=/boot/efi --removable --no-nvram
update-grub
CH
sync; umount -R /mnt || true
echo INSTALL_DONE
