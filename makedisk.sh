#!/bin/bash
# Creates a flashable UEFI disk image with root on ext4 and GRUB bootloader
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

ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p2")
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${LOOP}p2")

mkdir -p mnt/esp mnt/root
mount "${LOOP}p1" mnt/esp
mount "${LOOP}p2" mnt/root

echo "Installing root filesystem to disk..."
cp -a root/. mnt/root/
mkdir -p mnt/root/boot

echo "Installing kernel..."
cp vmlinuz.efi mnt/root/boot/vmlinuz

case "$(uname -m)" in
    x86_64)  GRUB_TARGET="x86_64-efi" ;;
    aarch64) GRUB_TARGET="arm64-efi" ;;
    *)       echo "Unsupported arch: $(uname -m)"; exit 1 ;;
esac

echo "Installing GRUB ($GRUB_TARGET)..."
grub-install \
    --target="$GRUB_TARGET" \
    --efi-directory=mnt/esp \
    --boot-directory=mnt/root/boot \
    --removable \
    --no-nvram

cat > mnt/root/boot/grub/grub.cfg << EOF
set default=0
set timeout=3

menuentry "odistro" {
    search --no-floppy --set=root --fs-uuid $ROOT_UUID
    linux /boot/vmlinuz root=PARTUUID=$ROOT_PARTUUID rw console=tty0 console=ttyS0,115200
}
EOF

sync
umount mnt/esp mnt/root
rmdir mnt/esp mnt/root mnt

echo "Done! Flash with:"
echo "  sudo dd if=$IMAGE of=/dev/sdX bs=4M status=progress"
