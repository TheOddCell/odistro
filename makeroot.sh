#!/bin/bash
set -o errexit
rm -rf busybox-1.37.0 musl-1.2.5 root musl-for-host musl-for-host-src
mkdir root
mkdir root/bin root/dev root/sys root/proc root/etc root/root
ln -s .. root/usr
cat>root/etc/inittab <<'EOF'
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mkdir -p /dev
::sysinit:/bin/mknod -m 600 /dev/console c 5 1

::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys

console::respawn:/bin/getty -L 115200 console vt100
EOF
echo 'root::0:0::/root:/bin/sh'>root/etc/passwd
cat>root/etc/os-release << 'EOF'
NAME="oDistro"
PRETTY_NAME="oDistro Busybox/Musl/Linux"
ID=odistro
BUILD_ID="1.37.0+1.2.5"
HOME_URL="https://github.com/theoddcell/odistro"
DOCUMENTATION_URL="https://github.com/theoddcell/odistro"
SUPPORT_URL="https://github.com/TheOddCell/odistro/issues"
BUG_REPORT_URL="https://github.com/TheOddCell/odistro/issues"
PRIVACY_POLICY_URL="data:text/html,<h1>we dont collect data</h1><h2>how would we</h2><title>odistro privacy policy</title>"
EOF
clear
echo "Downloading components..."
curl -fL https://busybox.net/downloads/busybox-1.37.0.tar.bz2 | tar -xvj &
curl -fL https://musl.libc.org/releases/musl-1.2.5.tar.gz | tar -xvz
clear
# ---------------
# host toolchain
# ---------------
echo "Musl (for host): configuring..."
cp -r musl-1.2.5 musl-for-host-src
mkdir musl-for-host
HOSTDIR="$(realpath ./musl-for-host)"
cd musl-for-host-src
./configure "--prefix=$HOSTDIR" "--enable-wrapper=all"
clear
echo "Musl (for host): compiling..."
make -j$(nproc)
make install
clear
# -----
# musl
# -----
echo "Musl: configuring..."
cd ../musl-1.2.5
./configure --prefix=/ --enable-wrapper=none
echo "Musl: compiling..."
make -j$(nproc)
make DESTDIR=../root install
clear
# --------
# busybox
# --------
echo "Busybox: configuring..."
wait
cd ../busybox-1.37.0
make defconfig
sed -i 's/CONFIG_TC=y/CONFIG_TC=n/g' .config
clear
echo "Busybox: compiling..."
LDFLAGS='-static' CC="$HOSTDIR/bin/musl-gcc" make -j$(nproc)
cp busybox ../root/bin/busybox
../root/bin/busybox --install ../root/bin
ln ../root/bin/busybox ../root/init
clear
cd ..
rm -rf busybox-1.37.0 musl-1.2.5 musl-for-host musl-for-host-src
