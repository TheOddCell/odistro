#!/bin/bash
set -o errexit
./makeroot.sh
clear
./makekern.sh
cd root
find . -print0 \
 | cpio --null -o --format=newc \
 | zstd -19 -T0 > ../initramfs-full.cpio.zst
cd ..
ukify build \
  --linux vmlinuz.efi \
  --initrd initramfs-full.cpio.zst \
  --cmdline "rw" --output "odistro.uki.efi"
rm vmlinuz.efi initramfs-full.cpio.zst -rf root
