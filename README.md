# SmallHam minimal linux – Educational System-Building Project

This project aims to create a minimal Linux system primarily for learning purposes. The goal is to gain a deep understanding of how a Linux-based system is constructed from the ground up, and how to assemble a working distribution using a modular approach with the Linux kernel, BusyBox, and optional components.
## Key Objectives:
- Practice compiling and configuring the Linux kernel
- Understand initramfs and kernel module handling
- Build a custom init system and boot process
- Integrate core utilities using BusyBox
- Configure the distribution using Kconfig and Makefiles
- Produce a bootable ISO image for QEMU/VirtualBox (VirtualBox is not recommended)
- **Enable amateur radio control testing on minimal hardware**

## Amateur Radio Support

This project includes amateur radio kernel modules (e.g., AX.25, MKISS, 6PACK, NET/ROM, ROSE), offering functionality tailored for the amateur radio community. One of the key objectives was to enable running the system on minimal hardware, making it suitable for simulating repeater stations or radio tower emulation on general-purpose computers.


## Configuration Options (menuconfig)

To customize the system, use the make menuconfig command. This lets you choose which features and modules are included in the initramfs and the final bootable system.

Each option corresponds to a .modlist file, defining which kernel modules will be copied into initroot/lib/modules/.
Available module options:

#### `HAM` – Hamradio drivers

- Enables support for AX.25, NetROM, ROSE, 6PACK, and other hamradio protocols.
- Use case: Amateur radio communication, tower emulation setups.

#### `FS` – Filesystem support
- Enables ext4, jbd2, mbcache, nls_base, and block device drivers like virtio_blk.
- Use case: Mounting storage, filesystem access.

#### `OVERLAY_FS` – Overlay filesystem support
- Enables overlayfs module for layered file access.
- Depends on: FS must be enabled.
- Use case: Writable layers over read-only rootfs, common in initramfs-based systems.

#### `NET` – Network drivers (VirtIO) support
- Enables virtio_net, net_failover, and related networking support.
- Use case: Provides eth0 or similar virtual NICs, usable in QEMU with -netdev.

#### `USB` – USB support (VirtIO)
- Enables USB core, EHCI/XHCI host controllers, and common USB infrastructure.
- Use case: Connect USB peripherals like serial adapters, USB sound cards, etc.

#### `USB_STORAGE` – USB mass storage (VirtIO) support
- Enables usb-storage, sd_mod, scsi_mod, and other storage-related modules.
- Depends on: USB must be enabled.
- Use case: Attach and access USB drives, flash disks.

#### `SOUND` – Sound driver support
- Loads sound modules like snd-core, snd-usb-audio, snd-pcm, etc.
- Use case: USB sound card output, digital modulation testing for hamradio.


The project is under active development, with new modules, configuration options, and tools being added regularly.

## Getting started
### Prerequisites 
#### Packages
```shell
sudo pacman -S syslinux
sudo pacman -S genisoiamge
sudo pacman -S kconfig-frontends
```

#### Clone this project
```shell
https://github.com/dandidev/small-linux.git
```

### Build mini linux
- Select modules
```shell
make menuconfig
```
- Create distro
```shell
make distro
```
- Create ISO
```shell
make iso
```

### Run with Qemu
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
- Create HDD
```
qemu-img create -f raw hdd.img 10M
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

### How to

#### Direwolf
- Configuration
```shell
echo "ADEVICE plughw:0,0" > /etc/direwolf.conf
```
- Run
```shell
direwolf -f 0 -c /etc/direwolf.conf
```

#### Strip all binaries in initroot
```shell
find initroot -type f -executable -exec strip {} \;
```

#### .img mount
```shell
sudo losetup -fP hdd.img
#losetup -a
#lsblk
sudo mount /dev/loop0p1 /mnt
```

#### Create ISO
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
#### Linux commands
###### Filesystem
```shell
# find connected disk and create partition
fdisk -l
# create ext4 fs
mke2fs /dev/vda1
```
###### Soundcard
```shell
ls -la /sys/class/sound/ 
cat /proc/asound/cards
lsusb
```
###### IP settings
```shell
ip link set eth0 up
udhcpc -i eth0
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2
```
### Under Construction

#### Package manager 
- Kiss package manager
```shell
git clone https://github.com/kisslinux/kiss.git
```
- TinyGCC
https://bellard.org/tcc/


# TODO's
- BusyBox build only used package -ok, but not enought
- Refactor HAM module into a selectable list format
- Bootchart optimalization
- init.cpio rename to initramfs.cpio
- Create module to kiss package manager (kiss pm, certs, wget ssl) - depend tinygcc
- Fix poweroff
- Config module size optimalization
- Extract module builds from the main Makefile into separate Makefiles
- Makefile packages move into separate dependencies
- USB modules->kernel/fs/nls/nls_base.ko->utf16s_to_utf8s() thinking
- Refactor lib module in MODMAP
- Testing all module
- Testing direwolf communication
- Testing netrom routing
- Testing digirig connection with direwolf
- Testing another linux (tested only Arch linux)