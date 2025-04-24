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