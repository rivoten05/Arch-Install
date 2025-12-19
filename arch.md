# Arch Linux Installation Guide (UEFI)
This guide covers the installation of Arch Linux on a UEFI system.

## 1. Pre-Installation
### Verify Boot Mode
Confirm you are in UEFI mode (should return 64)

cat /sys/firmware/efi/fw_platform_size

## connect to internet 
1. Enter the Interactive Prompt
iwctl

2. Find Your Device Name

device list

station wlan0 scan

station wlan0 get-networks

station wlan0 connect <"YourSSID">

Note: if the network name has spaces, wrap it in quotes: station wlan0 connect "My Home Wi-Fi"

Alternative: The One-Line Command

iwctl --passphrase YOUR_PASSWORD station wlan0 connect YOUR_SSID

Device Powered Off: If your device is listed but "Powered" is "off," run device wlan0 set-property Powered on

## check internet connection
ping -c 2 archlinux.org

#Connect to SSH
## give root password 
passwd

## check sshd is running
systemctl status sshd

## If it is not running, start it with: systemctl start sshd

## check IP
ip a

##connect to ssh on another computer both need to have in same network
ssh root@<IP-of-arch-live-environment>

2. Partitioning the Disk

## Identify your drive (e.g., /dev/nvme0n1 or /dev/sda):

lsblk

## Partitioning with cfdisk

cfdisk /dev/sda

## /dev/sda1 (EFI): 300M, Type: EFI System (ef00).
## /dev/sda2 (ROOT): Remaining space, Type: Linux filesystem (8300).

mkfs.fat -F32 /dev/sda1 # EFI
mkfs.btrfs /dev/sda2   # Root/Main

## Create Mount Points, Subvolumes & Mount
mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# Mount subvolumes with Btrfs options
mount -o noatime,compress=zstd,subvol=@ /dev/sda2 /mnt
mkdir -p /mnt /mnt/home /mnt/boot
mount -o noatime,compress=zstd,subvol=@home /dev/sda2 /mnt/home

# Mount EFI
mount /dev/sda1 /mnt/boot

# Phase 2: Base System Installation
pacstrap -K /mnt base linux linux-firmware base-devel btrfs-progs

# Configure Fstab & Chroot
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Phase 3: System Configuration
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime # Adjust timezone as needed
hwclock --systohc

locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

#hostname
echo "arch-btw" > /etc/hostname # Choose your hostname

#password for root 
passwd # Set root password
useradd -m -g users -G wheel rio # Replace rad
passwd rio

# Install sudo & neovim
pacman -S sudo neovim

#give user root access 
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers


# install core packages
pacman -S grub efibootmgr networkmanager bluez bluez-utils pipewire pipewire-pulse mesa ly git

#change btrfs
sudo sed -i 's/^MODULES=()$/MODULES=(btrfs)/' /etc/mkinitcpio.conf
# Change: MODULES=()  to  MODULES=(btrfs)

# Regenerate initramfs image
mkinitcpio -P

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable fstrim.timer

# 1. Disable the standard getty on TTY2
sudo systemctl disable ly@tty2.servic.service

# 2. Enable Ly on TTY2
sudo systemctl enable ly@tty2.service

#3. Graphical on target
sudo systemctl set-default graphical.target

## 4: Finalization
exit
umount -R /mnt
reboot

# connect to network using nmcli
nmcli device
nmcli device wifi list
nmcli device wifi connect "SSID_NAME" password "PASSWORD"
nmcli connection show
nmcli connection up "Wired connection 1"

## if network not up
sudo systemctl status NetworkManager

## ssh service
sudo yay -S openssh
sudo systemctl start sshd
sudo systemctl enable sshd
sudo systemctl status sshd

## if firewall is set
sudo ufw allow ssh
# OR
sudo ufw allow 22/tcp

## Post installation 
# Install yay
# 1. Install dependencies
sudo pacman -S --needed base-devel git

# 2. Clone and install yay-bin (which is already fixed)
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si

# 3. Test it
yay --version

## Backup with timeshift
yay -S timeshift

sudo timeshift --create --comments "First backup after fixing AUR" --tags O

sudo timeshift --list

sudo timeshift --restore

sudo timeshift --delete --snapshot '2025-12-17_15-00-00'

sudo timeshift --delete-all

## Install Your Desktop Enviroment Like Qtile, Cosmic, Hyprland, oxwm, xfce4, Gnome etc..
sudo yay -S qtile xorg-server
sudo yay -S cosmic

