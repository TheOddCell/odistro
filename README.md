# oDistro
oDistro is a set of 2.5 scripts that can be used to make a bootable system.

## `makeroot.sh`
Creates a root file system by compiling musl (twice) and busybox

## `makereg.sh`
Uses `makeroot.sh` to make a rootfs and compiles it as an initramfs into a compiled efistub kernel

## `makeuki.sh`
Uses `makeroot.sh` to make a rootfs, compiles the kernel, and uses systemd's ukify to make it into a bootable efi
