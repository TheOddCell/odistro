#!/bin/bash
# odistro 1.37.0+1.2.5 rootfs builder
ODISTROVERSION="1.37.0+1.2.5"
set -o errexit
rm -rf busybox-1.37.0 musl-1.2.5 root musl-for-host musl-for-host-src openssl-3.5.0 curl-8.12.0 wpa_supplicant-2.11
mkdir root
mkdir root/bin root/dev root/sys root/proc root/etc root/root
ln -s .. root/usr
cat>root/etc/inittab <<'EOF'
::sysinit:/bin/mkdir -p /dev
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mknod /dev/console c 5 1
::sysinit:/bin/mknod /dev/null c 1 3
::sysinit:/bin/mknod /dev/zero c 1 5
::sysinit:/bin/mknod /dev/full c 1 7
::sysinit:/bin/mknod /dev/random c 1 8
::sysinit:/bin/mknod /dev/urandom c 1 9
::sysinit:/bin/mknod /dev/tty c 5 0
::sysinit:/bin/mknod /dev/ptmx c 5 2
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/ln -s /proc/self/mounts /etc/mtab

console::respawn:/bin/getty -L 115200 console vt100

::shutdown:/bin/umount -a -r
EOF
echo 'root::0:0:root:/root:/bin/sh' > root/etc/passwd
echo 'root:x:0:'>root/etc/group
cat>root/etc/profile << 'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PS1='\u@\h:\w\$ '
EOF
echo "Welcome to oDistro Busybox/Musl/Linux $ODISTROVERSION" > root/etc/issue
echo 'odistro'>root/etc/hostname
echo '127.0.0.1 localhost'>root/etc/hosts
cat>root/etc/os-release << EOF
NAME='oDistro'
PRETTY_NAME='oDistro Busybox/Musl/Linux'
ID=odistro
BUILD_ID='$ODISTROVERSION'
HOME_URL='https://github.com/theoddcell/odistro'
DOCUMENTATION_URL='https://github.com/theoddcell/odistro'
SUPPORT_URL='https://github.com/TheOddCell/odistro/issues'
BUG_REPORT_URL='https://github.com/TheOddCell/odistro/issues'
PRIVACY_POLICY_URL='data:text/html,<h1>we dont collect data</h1><h2>how would we</h2><title>odistro privacy policy</title>'
EOF
clear
echo "Downloading components..."
curl -fL https://mirrors.slackware.com/slackware/slackware64-current/source/a/mkinitrd/busybox-1.37.0.tar.bz2 | tar -xvj &
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
# --------
# openssl (dep for curl + wpa_supplicant)
# --------
echo "Downloading OpenSSL..."
curl -fL https://www.openssl.org/source/openssl-3.5.0.tar.gz | tar -xvz
ROOTDIR="$(realpath ./root)"
echo "OpenSSL: configuring..."
cd openssl-3.5.0
CC="$HOSTDIR/bin/musl-gcc" ./Configure no-shared no-zlib no-secure-memory no-afalgeng no-module linux-x86_64 --prefix=/ --openssldir=/etc/ssl --libdir=/lib
echo "OpenSSL: compiling libs..."
make -j$(nproc) build_libs
make DESTDIR="$ROOTDIR" install_dev
mkdir -p "$ROOTDIR/etc/ssl/certs" "$ROOTDIR/etc/ssl/private"
echo "Downloading CA certificates..."
curl -fL https://curl.se/ca/cacert.pem -o "$ROOTDIR/etc/ssl/certs/ca-certificates.crt"
cd ..
clear
# ------
# curl
# ------
echo "Downloading curl..."
curl -fL https://curl.se/download/curl-8.12.0.tar.gz | tar -xvz
ROOTDIR="$(realpath ./root)"
echo "curl: configuring..."
cd curl-8.12.0
CC="$HOSTDIR/bin/musl-gcc" \
    LDFLAGS="-static -L$ROOTDIR/lib" \
    CFLAGS="-I$ROOTDIR/include -fno-link-libatomic" \
    PKG_CONFIG_PATH="$ROOTDIR/lib/pkgconfig" \
    ./configure --prefix=/ --disable-shared --enable-static \
        --with-openssl --without-libpsl --without-brotli --without-zstd --without-zlib
echo "curl: compiling..."
make -j$(nproc)
make DESTDIR="$ROOTDIR" install
cd ..
clear
# ----------------
# wpa_supplicant
# ----------------
echo "Downloading wpa_supplicant..."
curl -fL https://w1.fi/releases/wpa_supplicant-2.11.tar.gz | tar -xvz
ROOTDIR="$(realpath ./root)"
echo "wpa_supplicant: configuring..."
cd wpa_supplicant-2.11/wpa_supplicant
cat > .config << 'WPACFG'
CONFIG_DRIVER_WEXT=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_TLS=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TTLS=y
CONFIG_TLS=openssl
CONFIG_INTERNAL_LIBTOMMATH=y
WPACFG
echo "wpa_supplicant: compiling..."
CC="$HOSTDIR/bin/musl-gcc" \
    CFLAGS="-I$ROOTDIR/include -I/usr/include -fno-link-libatomic" \
    LIBS="-static -fno-link-libatomic -L$ROOTDIR/lib -lssl -lcrypto" \
    make -j$(nproc)
cp wpa_supplicant wpa_cli "$ROOTDIR/bin/"
cd ../..  
clear
rm -rf busybox-1.37.0 musl-1.2.5 musl-for-host musl-for-host-src openssl-3.5.0 curl-8.12.0 wpa_supplicant-2.11
