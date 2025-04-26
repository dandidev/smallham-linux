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
./configure --prefix=/usr --enable-static
make
make DESTDIR=../../initroot/ install
```

## ax25-tools (TODO: push new code)
```shell
./configure \
  --prefix=/usr \
  CPPFLAGS="-I$PWD/../../initroot/usr/include" \
  LDFLAGS="-L$PWD/../../initroot/usr/lib"

./configure --prefix=/usr --without-x
make LDFLAGS="-static" -j4
make DESTDIR=../../initroot/ install
```

## ax25-apps (TODO: push new code)
```shell
./configure \
  --prefix=/usr \
  CPPFLAGS="-I$PWD/../../initroot/usr/include" \
  LDFLAGS="-L$PWD/../../initroot/usr/lib"
make
make DESTDIR=../../initroot/ install
```

# Qemu
```shell
qemu-system-x86_64 -kernel arch/x86/boot/bzImage -initrd ../../init.cpio -append notsc
```

# TODO's
- strip apply to binaries