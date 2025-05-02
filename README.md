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
- General setup
- - Initial RAM filesystem and RAM disk
- - Only Initramfs source files
- - Configure standard kernel features (exprt users)
- - - Enable support for printk
- - - Enabled futex support
- - - Posix Clocks & timers /CONFIG_POSIX_TIMERS=y/
- Device drivers
- - Character drivers
- - - Enable TTY
- - Network driver support
- - - Network core driver support
- - - Ethernet driver support
- - - - Intel E1000 driver, AMD PCnet32 driver
- - - OFF: Wireless LAN
- - OFF: HID bus support
- - OFF: I2C support
- - Input device support
- - - OFF: Mice
- - Misc devices
- - - OFF: Intel Management Engine Interface
- Executable file formats
- - Kernel support for ELF binaries
- Network support
- - Amateur Radio sipport -> ALL and ALL SUB
- - Netlink interface for ethtool
- Netwok options
- - Packet socket
- - Unix domain socket
- - TCP/IP networking
- - - INET: socket monitoring interface
- - - UDP: socker monitoring interface
- - - IP: kernel level autoconfiguration
- - - IP: DHCP support
- - - OFF: IPv6 protocol
- TSC clocksource support
- OFF: Bus options
- File systems
- - Presudo filesystems
- - /proc file system support
- - /sys file system support
```shell
cat .config | grep CONFIG_X86_TSC
sed -i 's/CONFIG_X86_TSC=y/# CONFIG_X86_TSC is not set/' .config
```
- Device Drivers
- - Generic Driver Options
- - - Maintain a devtmpfs filesystem to mount at /dev
- - - Automount devtmpfs at /dev, after the kernel mounted the rootfs

```shell
cat .config | grep CONFIG_DEBUG_KERNEL
sed -i 's/CONFIG_DEBUG_KERNEL=y/CONFIG_DEBUG_KERNEL=n/' .config
```

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

# IP settings
```shell
ip link set eth0 up
udhcpc -i eth0
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2
```

# TODO's
- busybox build only used package -ok, but not enought
- full build use makefile
- makefile build switch option: basic, ham, etc
- bootchart optimalization
- makefile add required tools
- init.cpio rename to initramfs.cpio
- create module to overlayfs support
- create module to kiss package manager (kiss pm, certs, wget ssl)
- az alaprendszerből is lehessen akár kézzel felépíteni
- fix poweroff
- confg mosule compression how to
- usb modules->kernel/fs/nls/nls_base.ko->utf16s_to_utf8s() thinking