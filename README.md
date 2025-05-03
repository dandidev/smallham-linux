# Required packages
```shell
sudo pacman -S syslinux
sudo pacman -S genisoiamge
sudo pacman -S kconfig-frontends
```

# Init folders
```shell
mkdir sources
```

# Clone Linux kernel
```shell
cd sources
git clone --depth 1 --branch master https://github.com/torvalds/linux.git
```

# Clone BusyBox
```shell
cd sources
git clone https://git.busybox.net/busybox
```

# Build mini linux
- Select modules
```shell
make menuconfig
```
- Build kernel with modules
```shell
make -j$(nproc) all
```
- Create distro
```shell
make distro
```
- Create ISO
```shell
make iso
```

# Qemu
- Run linux
```
qemu-system-x86_64 -m 40 
  -kernel build/current/kernel/arch/x86/boot/bzImage \
  -initrd build/current/init.cpio \
  -append notsc
```
- Run linux from ISO
```
qemu-system-x86_64 -m 40 \
  -cdrom build/current/my-linux.iso \
  -boot d
```
- Run linux from ISO with hdd
```
qemu-system-x86_64 -m 40 \
  -cdrom build/current/my-linux.iso \
  -drive file=hdd.img,if=virtio,format=raw \
  -boot d
```
- Run linux from ISO with usb sound card
```
qemu-system-x86_64 -m 40 \
  -cdrom build/current/my-linux.iso \
  -drive file=hdd.img,if=virtio,format=raw \
  -device qemu-xhci \
  -device usb-host,vendorid=0x08bb,productid=0x2902 \
  -boot d 
```
- Run linux from ISO with network
```
qemu-system-x86_64 -m 40 \
  -cdrom build/current/my-linux.iso \
  -netdev user,id=mynet0 \
  -device virtio-net-pci,netdev=mynet0 \
  -boot d
```
- Run linux from ISO with network and hdd
```
qemu-system-x86_64 -m 40 \
  -cdrom build/current/my-linux.iso \
  -netdev user,id=mynet0 \
  -device virtio-net-pci,netdev=mynet0 \
  -drive file=hdd.img,if=virtio,format=raw \
  -boot d
```

# Install ham tools
## download
https://linux-ax25.in-berlin.de/pub/

## ax25-lib
```shell
#autoreconf -fi
CFLAGS="-Os" LDFLAGS="-s" ./configure --prefix=/usr --enable-static
make -j$(nproc)
make DESTDIR=../../initroot/ install
```

## ax25-tools (TODO: push new code)
```shell
CFLAGS="-Os" LDFLAGS="-s" ./configure \
  --prefix=/usr \
  CPPFLAGS="-I$PWD/../../initroot/usr/include" \
  LDFLAGS="-L$PWD/../../initroot/usr/lib" \
  --prefix=/usr --without-x
make LDFLAGS="-static" -j$(nproc)
make DESTDIR=../../initroot/ install
```

## ax25-apps (TODO: push new code)
```shell
# libtoolize --force --copy
# aclocal
# autoheader
# automake --add-missing
# autoconf
CFLAGS="-Os" LDFLAGS="-s" ./configure \
  --prefix=/usr \
  CPPFLAGS="-I$PWD/../../initroot/usr/include" \
  LDFLAGS="-L$PWD/../../initroot/usr/lib"
make -j$(nproc)
make DESTDIR=../../initroot/ install
```

# Strip all binaries in initroot
```shell
find initroot -type f -executable -exec strip {} \;
```


# Create ISO
- dependencies
- - sudo pacman -S syslinux
- - sudo pacman -S genisoiamge
- script
```shell
# sudo pacman -S syslinux
mkdir -p iso/isolinux
cp /usr/lib/syslinux/bios/isolinux.bin iso/isolinux
cp /usr/lib/syslinux/bios/ldlinux.c32 iso/isolinux
cp init.cpio iso
cp cloned/linux/arch/x86/boot/bzImage iso
genisoimage -o mylinux.iso \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -iso-level 3 -quiet \
  iso/
```
# Linux commands
## Filesystem
```shell
# find connected disk and create partition
fdisk -l
# create ext4 fs
mke2fs /dev/vda1
```
## Soundcard
```shell
ls -la /sys/class/sound/ 
cat /proc/asound/cards
lsusb
```
## Network
### IP settings
```shell
ip link set eth0 up
udhcpc -i eth0
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2
```
# TODO's
- busybox build only used package -ok, but not enought
- bootchart optimalization
- makefile add required tools
- init.cpio rename to initramfs.cpio
- create module to kiss package manager (kiss pm, certs, wget ssl)
- fix poweroff
- config module compression how to
- usb modules->kernel/fs/nls/nls_base.ko->utf16s_to_utf8s() thinking