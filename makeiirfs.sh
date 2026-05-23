#!/bin/bash
set -o errexit
rm -rf linux-7.0.8
curl -fL https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.8.tar.xz | tar -xJ &
./makeroot.sh
clear
cd root
find . -print0 \
 | cpio --null -o --format=newc \
 | zstd -19 -T0 > ../root.cpio.zst
cd ..
echo "Downloading linux..."
wait
clear
cd linux-7.0.8
clear
echo "linux: configuring..."
make 												defconfig
sed -i 's/=m$$/=y/'										  .config
sed -i 's/(none)/odistro/g' 									  .config
sed -i 's/# CONFIG_SQUASHFS is not set/CONFIG_SQUASHFS=y/'				  .config
sed -i 's/# CONFIG_OVERLAY_FS is not set/CONFIG_OVERLAY_FS=y/'				  .config
sed -i 's/# CONFIG_FUSE_FS is not set/CONFIG_FUSE_FS=y/'				  .config
sed -i 's|CONFIG_INITRAMFS_SOURCE=""|CONFIG_INITRAMFS_SOURCE="../root.cpio.zst"|'	  .config
yes '' | make 											oldconfig
sed -i 's/# CONFIG_SQUASHFS_LZ4 is not set/CONFIG_SQUASHFS_LZ4=y/'			  .config
sed -i 's/# CONFIG_SQUASHFS_LZO is not set/CONFIG_SQUASHFS_LZO=y/'			  .config
sed -i 's/# CONFIG_SQUASHFS_XZ is not set/CONFIG_SQUASHFS_XZ=y/'			  .config
sed -i 's/# CONFIG_SQUASHFS_ZSTD is not set/CONFIG_SQUASHFS_ZSTD=y/'			  .config
yes '' | make 											oldconfig
clear
echo "linux: compiling..."
make -j$(nproc)
cd ..
cp linux-7.0.8/arch/$(uname -m)/boot/bzImage odistro.vmlinuz.efi
rm -rf linux-7.0.8 root root.cpio.zst
