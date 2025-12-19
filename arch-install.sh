#!/bin/bash

# Arch Linux UEFI Installation Script (BTRFS with subvolumes)
# WARNING: This script will ERASE the selected disk. Use with extreme caution!
# Run this script in the Arch Linux live environment.
# Customize variables below before running.

# === USER CONFIGURATION ===
DISK="/dev/sda"                  # CHANGE THIS! e.g., /dev/nvme0n1
EFI_SIZE="512M"                  # EFI partition size (512M recommended)
TIMEZONE="Asia/Kolkata"          # Your timezone
LOCALE="en_US.UTF-8"             # Your locale
KEYMAP="us"                      # Console keymap
HOSTNAME="arch-btw"              # Your hostname
USERNAME="rio"                   # Your username
ROOT_PASS="rootpassword"         # Root password (will prompt if empty)
USER_PASS="userpassword"         # User password (will prompt if empty)
USE_LY="yes"                     # Install and enable Ly display manager? (yes/no)
# ==========================

set -e  # Exit on any error

echo "=== Arch Linux UEFI Installation Script ==="
echo "Disk: $DISK  |  Timezone: $TIMEZONE  |  User: $USERNAME"
read -p "Continue? This will DESTROY all data on $DISK (y/N): " confirm
[[ $confirm != "y" && $confirm != "Y" ]] && echo "Aborted." && exit 1

# Verify UEFI
if [[ $(cat /sys/firmware/efi/fw_platform_size) != "64" ]]; then
    echo "Not in UEFI mode!"
    exit 1
fi

# Update system clock
timedatectl set-ntp true

# Update mirrors (optional but recommended)
pacman -Syy --noconfirm reflector
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Partition the disk
echo "Partitioning $DISK..."
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB $EFI_SIZE
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary btrfs $EFI_SIZE 100%

# Format partitions
mkfs.fat -F32 ${DISK}1
mkfs.btrfs -f ${DISK}2

# Create BTRFS subvolumes
mount ${DISK}2 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
umount /mnt

# Mount subvolumes
mount -o noatime,compress=zstd,commit=120,subvol=@ ${DISK}2 /mnt
mkdir -p /mnt/{boot,home,.snapshots}
mount -o noatime,compress=zstd,commit=120,subvol=@home ${DISK}2 /mnt/home
mount -o noatime,compress=zstd,commit=120,subvol=@snapshots ${DISK}2 /mnt/.snapshots
mount ${DISK}1 /mnt/boot

# Install base system
pacstrap -K /mnt base linux linux-firmware btrfs-progs base-devel neovim git networkmanager

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot configuration
cat <<CHROOT | arch-chroot /mnt
set -e

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale
sed -i "/$LOCALE/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Keyboard
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname & hosts
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Root password
if [[ -n "$ROOT_PASS" ]]; then
    echo "root:$ROOT_PASS" | chpasswd
else
    passwd
fi

# Create user
useradd -m -G wheel $USERNAME
if [[ -n "$USER_PASS" ]]; then
    echo "$USERNAME:$USER_PASS" | chpasswd
else
    passwd $USERNAME
fi

# Enable sudo for wheel
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Network
systemctl enable NetworkManager

# Initramfs
mkinitcpio -P

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Optional: Ly display manager
if [[ "$USE_LY" == "yes" || "$USE_LY" == "y" ]]; then
    pacman -S --noconfirm ly
    systemctl disable getty@tty2.service
    systemctl enable ly.service
    systemctl set-default graphical.target
fi

CHROOT

# Final cleanup
umount -R /mnt

echo "=== Installation complete! ==="
echo "Remove installation media and run: reboot"
echo "After reboot, consider installing an AUR helper (yay) and your desktop environment."