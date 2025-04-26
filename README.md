# init folders
```shell
mkdir cloned
mkdir initroot
```

# clone linux kernel
git clone --depth 1 --branch master https://github.com/torvalds/linux.git

# Kernel config
make tinyconfig
make menuconfig

## Settings
- 64-bit kernel
- General setuo
- - Initial RAM filesystem and RAM disk
- - Only Initramfs source files
- - Configure standard kernel features (exprt users)
- - - Enable support for printk
- Device drivers
- - Character drivers
- - - Enable TTY
- Executable file formats
- - Kernel support for ELF binaries
- Network support
- - Amateur Radio sipport -> ALL and ALL SUB
- - Netlink interface for ethtool
- TSC clocksource support
```shell
cat .config | grep CONFIG_X86_TSC
sed -i 's/CONFIG_X86_TSC=y/# CONFIG_X86_TSC is not set/' .config
- Device Drivers
- - Generic Driver Options
- - - Maintain a devtmpfs filesystem to mount at /dev
- - - Automount devtmpfs at /dev, after the kernel mounted the rootfs
``` 
# Make
make -j 4

# Clone Busybox
```shell
git clone https://git.busybox.net/busybox
```

## Budybox config
```shell
make defconfig
make menuconfig
```
- Don't use /usr
- Build static binary

## Make
```shell
make -j 4
```

# Create symlinks to commands
```shell
chmod +x setup-links.sh
./setup-links.sh
```

# Create init
```shell
 chmod +x create-initramfs.sh
 ./create-initramfs.sh
```

# run Qemu
```shell
qemu-system-x86_64 -kernel arch/x86/boot/bzImage -initrd ../../init.cpio
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

# Qemu
```shell
qemu-system-x86_64 -kernel arch/x86/boot/bzImage -initrd ../../init.cpio -append notsc
```

# Create ISO
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

# TODO's