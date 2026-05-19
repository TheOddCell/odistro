#!/bin/bash
# Creates a flashable UEFI disk image with root on ext4 (not in RAM)
# Usage: ./makedisk.sh [image.img] [size]
# Example: ./makedisk.sh odistro.img 2G
set -o errexit

IMAGE="${1:-odistro.img}"
DISK_SIZE="${2:-2G}"

./makeroot.sh
./makekern.sh

echo "Creating disk image ($DISK_SIZE)..."
truncate -s "$DISK_SIZE" "$IMAGE"

parted -s "$IMAGE" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 101MiB \
    set 1 esp on \
    mkpart root ext4 101MiB 100%

LOOP=$(losetup -f --show -P "$IMAGE")

cleanup() {
    umount -q mnt/esp 2>/dev/null || true
    umount -q mnt/root 2>/dev/null || true
    rmdir mnt/esp mnt/root mnt 2>/dev/null || true
    losetup -d "$LOOP" 2>/dev/null || true
    rm -f vmlinuz.efi
    rm -rf root
}
trap cleanup EXIT

mkfs.fat -F32 -n ESP "${LOOP}p1"
mkfs.ext4 -L odistro-root "${LOOP}p2"

ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${LOOP}p2")

mkdir -p mnt/esp mnt/root
mount "${LOOP}p1" mnt/esp
mount "${LOOP}p2" mnt/root

echo "Installing root filesystem to disk..."
cp -a root/. mnt/root/
sync
umount mnt/root
rmdir mnt/root

case "$(uname -m)" in
    x86_64)  EFI_FALLBACK="BOOTX64.EFI" ;;
    aarch64) EFI_FALLBACK="BOOTAA64.EFI" ;;
    *)       EFI_FALLBACK="BOOT.EFI" ;;
esac
mkdir -p "mnt/esp/EFI/BOOT"

echo "Building UKI for disk boot..."
ukify build \
    --linux vmlinuz.efi \
    --cmdline "root=PARTUUID=$ROOT_PARTUUID rw console=tty0 console=ttyS0,115200" \
    --output "mnt/esp/EFI/BOOT/$EFI_FALLBACK"

sync
umount mnt/esp
rmdir mnt/esp mnt

echo "Done! Flash with:"
echo "  sudo dd if=$IMAGE of=/dev/sdX bs=4M status=progress"
