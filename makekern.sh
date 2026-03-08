#!/bin/bash
set -o errexit
curl -fL https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.tar.xz | tar -xvJ
clear
cd linux-6.19
clear
echo "linux: configuring..."
make defconfig
sed -i 's/=m$$/=y/'								  .config
sed -i 's/(none)/odistro/g' 							  .config
sed -i 's/# CONFIG_SQUASHFS is not set/CONFIG_SQUASHFS=y/'			  .config
sed -i 's/# CONFIG_OVERLAY_FS is not set/CONFIG_OVERLAY_FS=y/'			  .config
sed -i 's/# CONFIG_FUSE_FS is not set/CONFIG_FUSE_FS=y/'			  .config
yes '' | make 									oldconfig
sed -i 's/# CONFIG_SQUASHFS_LZ4 is not set/CONFIG_SQUASHFS_LZ4=y/'		  .config
sed -i 's/# CONFIG_SQUASHFS_LZO is not set/CONFIG_SQUASHFS_LZO=y/'		  .config
sed -i 's/# CONFIG_SQUASHFS_XZ is not set/CONFIG_SQUASHFS_XZ=y/'		  .config
sed -i 's/# CONFIG_SQUASHFS_ZSTD is not set/CONFIG_SQUASHFS_ZSTD=y/'		  .config
yes '' | make oldconfig
clear
echo "linux: compiling..."
make -j$(nproc)
cd ..
cp linux-6.19/arch/$(uname -m)/boot/bzImage vmlinuz.efi
rm -rf linux-6.19
