# SmallHam minimal linux – Educational System-Building Project

This project builds a very small Linux system, mainly for learning. You can see
how a Linux system is put together from the ground up: the Linux kernel,
BusyBox and a few optional programs. The system is 64-bit (x86_64); the output
file names show it, e.g. `smallham-ham-x86_64.iso`.

## Key Objectives:
- Practice compiling and configuring the Linux kernel
- Understand initramfs and the boot process
- Build a custom init system
- Integrate core utilities using BusyBox
- Configure the system with Kconfig and Makefiles
- Make images that run in QEMU and VirtualBox
- **Enable amateur radio control testing on minimal hardware**

## Amateur Radio Support

The system can include amateur radio support: AX.25, NET/ROM, ROSE, MKISS
(KISS) and 6PACK in the kernel, and the AX.25 tools and Dire Wolf (a sound card
modem) as programs. The goal is to run it on minimal hardware, for example to
simulate repeater stations or radio towers on ordinary computers.

## Requirements

### For building
- An x86_64 Linux computer. The build was tested on Arch Linux.
- Internet access: `make` downloads the sources (Linux kernel, BusyBox, musl, ...).
- No root access is needed.
- Free disk space:

| Configuration | Free space needed | Used after the build |
|---|---|---|
| Base image (`defconfig`) | about 2 GB | about 1.8 GB |
| Ham radio setup (`ham_defconfig`) | about 2.5 GB | about 2.1 GB |

Most of it is the kernel source (1.5 GB). The images themselves are only a few MB.

Packages (Arch Linux):
```shell
sudo pacman -S base-devel bc git curl cmake libelf squashfs-tools e2fsprogs util-linux qemu-system-x86
# for the VirtualBox ISO:
sudo pacman -S syslinux cdrtools qemu-img
```
`kconfig-frontends` (`kconfig-mconf`, `kconfig-conf`) is not in the official
repositories. Install it from the AUR, for example with an AUR helper:
```shell
yay -S kconfig-frontends
```

### For running
You only need the built files and one of these programs:
- **QEMU**: `qemu-system-x86_64` (tested with QEMU 11.1)
- **VirtualBox**: version 6.1 or newer, because the disk needs the VirtIO SCSI controller (tested with 7.2)

Memory (RAM) for the virtual machine:

| Configuration | Smallest RAM that boots | Recommended RAM |
|---|---|---|
| Base image | 16 MB | 16 MB |
| Ham radio setup | 20 MB (24 MB to run Dire Wolf) | 32 MB |

## Getting started
### Clone this project
```shell
git clone https://github.com/dandidev/smallham-linux.git
cd smallham-linux
```

### Quick start
Build the base image and start it in QEMU:
```shell
make defconfig
make
make run        # type 'reboot' to leave
```

## System size
Measured sizes of the built system:

| | Base image (`defconfig`) | Ham radio setup (`ham_defconfig`) |
|---|---|---|
| Kernel (`bzImage`) | 813 KB | 1.6 MB |
| initramfs | 113 KB (the whole system) | 11 KB (only the disk mounter) |
| Root filesystem | inside the initramfs | 1.0 MB squashfs in the disk image (192 KB without the ham programs) |
| **Total on disk** | **926 KB** | **2.6 MB** (the disk image itself is 8 MB with free space) |
| VirtualBox ISO | 1.4 MB | 2.2 MB (+ 1.2 MB `.vmdk` disk) |
| RAM used after boot | 1.5 MB | 5.2 MB (8.8 MB with Dire Wolf running) |

The ham programs in the root filesystem (xz compressed): Dire Wolf 490 KB,
`call` 246 KB, ALSA configuration 147 KB, `kissattach` + `kissparms` +
`netromd` 108 KB, Dire Wolf data files 52 KB.

## Configuration (menuconfig)

The base image has only the kernel and a BusyBox shell. You add every other
feature with `make menuconfig`:

```shell
make defconfig            # base image (used when there is no .config)
make ham_defconfig        # ham radio setup: disk, network, USB sound, AX.25, Dire Wolf
make base_vbox_defconfig  # base image for VirtualBox (ISO)
make ham_vbox_defconfig   # ham radio setup for VirtualBox (ISO + disk)
make menuconfig           # add or remove features
make savedefconfig        # save the current selection to ./defconfig
```
To keep a selection, copy `./defconfig` to `configs/<name>_defconfig`. Then
`make <name>_defconfig` loads it.

In `make menuconfig` press `?` to read the help of an option.

How the options are used:

| What | Where | How |
|---|---|---|
| Kernel | `configs/kernel/*.config` | starts with everything off (`allnoconfig`), then adds the files of the selected options; all drivers are built in (no modules) |
| BusyBox | `configs/busybox/*.config` | the same way as the kernel |
| Root filesystem | `rootfs/<name>/` | the selected directories are copied over each other (`base` always) |
| Programs | `packages/*.mk` | built with musl and copied to the root filesystem |

`scripts/check-config.sh` stops the build if an option did not get into the
final config. This happens with a misspelled option name or a missing dependency.

#### Profile
A profile turns on a group of options with one choice. You can still turn off
any option of the group or add others. Your changes are kept when you change
the profile later.
- `None` – no group (the base image)
- `Persistent system` – persistent disk, network, common tools, vi, system log (no ham radio)
- `Ham radio station` – the same as `make ham_defconfig`

#### System
- **Image name**: part of the output file names. By default it comes from the profile and the platform (`base`, `persistent`, `ham`, with `-vbox` for VirtualBox)
- **Target platform**: `QEMU` (disk: virtio-blk, `/dev/vda`) or `VirtualBox (ISO)` (disk: VirtIO SCSI, `/dev/sda`)
- **Root filesystem**:
  - `initramfs only`: the whole system is in RAM, changes are lost on reboot
  - `Persistent disk`: a read-only squashfs plus a writable ext2 partition, joined with overlayfs (`fs_init`); changes are kept
- **Console**: VGA screen and PS/2 keyboard, or serial port (`ttyS0`, QEMU runs with `-nographic`)
- **ACPI**: `poweroff` switches off the virtual machine (without it use `reboot`)

#### Kernel drivers
- `NET` – network (virtio-net, IPv4, DHCP with `ifup` and `udhcpc`)
- `USB` – USB host controllers (xHCI, EHCI), for USB devices passed to the VM
- `USB_STORAGE` – USB drives, with FAT filesystem
- `SOUND` – USB sound cards (ALSA)
- `HAM` – AX.25, NET/ROM, ROSE, MKISS (KISS), 6PACK, BPQ, Baycom, YAM, pseudo terminals

#### Userspace
- `BB_TOOLS` – grep, sed, find, head, tail, less, top, ...
- `BB_EDITOR` – vi
- `BB_SYSLOG` – syslogd, logread

#### Extras
- AX.25 tools (`kissattach`, `kissparms`, `netromd`), AX.25 apps (`call`, `listen`, `ax25ipd`), Dire Wolf, `aplay`
- Default config files, if you want them: `/usr/etc/ax25/axports`, `/etc/direwolf.conf`

### Adding a kernel feature
A feature has three parts: a Kconfig option, a config file and a few lines in
the Makefile. Example: USB serial adapters (CP210x).
1. `Kconfig`:
```
config USB_SERIAL
    bool "USB serial adapters (CP210x)"
    depends on USB
```
2. `configs/kernel/usb-serial.config`:
```
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CP210X=y
```
3. `Makefile`, next to the other options:
```make
ifeq ($(CONFIG_USB_SERIAL),y)
KERNEL_FRAGMENTS += usb-serial
endif
```
BusyBox commands (`BUSYBOX_FRAGMENTS`) and root filesystem files (`ROOTFS_OVERLAYS`)
are added the same way.

### Adding a package
A package is a `packages/<name>.mk` file. The main Makefile includes it. The
file tells what to build and what to copy with three lists (`FEATURE` is a
Kconfig option without `CONFIG_`):
```make
PKG_FEATURES += FEATURE|<make target>              # build it
PKG_BINS     += FEATURE|<built program>            # copy it to /usr/bin
PKG_DIRS     += FEATURE|<built dir>:<rootfs dir>    # copy a data directory
```
Build the programs as static binaries with `$(MUSL_CC)`. See `packages/ax25-tools.mk`.

## Build
```shell
make
```
The output files are in `build/out/`. Their names are
`smallham-<image name>-x86_64-...`, so the files of different configurations
(and later of other architectures) do not overwrite each other. `make dbg-vars`
shows the name for your configuration.

| File (example: `ham_defconfig`) | What it is |
|---|---|
| `smallham-ham-x86_64-bzImage` | the kernel |
| `smallham-ham-x86_64-initramfs.cpio.xz` | the initramfs (the whole system, or only `fs_init` with the persistent disk) |
| `smallham-ham-x86_64-disk.img` | the disk image, only with `Persistent disk` |

Partitions of the disk image:

| Partition | Content | Used as |
|---|---|---|
| 1 (`vda1`) | squashfs (xz), read-only root | lower layer of the overlay |
| 2 (`vda2`) | ext2, writable | upper layer of the overlay (your changes) |

Note: `make` builds the disk image again, and this deletes your changes on the
writable partition. You can change the sizes, e.g. `make DISK_SIZE_MB=16 SQUASHFS_SIZE_MB=8`.

Make targets:

| Target | What it does |
|---|---|
| `make` | builds the kernel, the initramfs and the disk image |
| `make run` | starts the system in QEMU |
| `make iso` | makes the VirtualBox ISO (and `.vmdk`) |
| `make menuconfig`, `defconfig`, `<name>_defconfig`, `oldconfig`, `savedefconfig` | configuration |
| `make IMAGE_NAME=<name>` | build with another image name (other output file names) |
| `make dbg-vars` | shows the selected config files, packages and the kernel command line |
| `make clean-distro` | deletes the root filesystem and the output files, except the disk image |
| `make clean` | deletes everything, also the downloaded sources (~2 GB to download again) |

## Run
### Run with Qemu (make run)
`make run` builds the kernel and the initramfs if the configuration changed,
then starts QEMU. It does not build the disk image again if it exists, so your
changes are kept. Run `make` if you changed what goes into the root filesystem.
```shell
make run                      # default RAM: 30 MB
make run QEMU_MEM=20          # change RAM size (MB)
make run QEMU_EXTRA="-device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902"
```
`QEMU_EXTRA` is given to QEMU as it is. The example passes a USB device of
your computer to the VM. Use the ids from `lsusb` on your computer; QEMU must
have access to `/dev/bus/usb`. With `NET` the VM uses QEMU's user network
(`udhcpc` gets `10.0.2.15`).

To leave the system type `reboot`. QEMU runs with `-no-reboot`, so it stops
instead of starting again. With the ACPI option `poweroff` works too.
With the serial console leave QEMU with `Ctrl-A X`.

### Run with Qemu (without make)
You can copy the files from `build/out/` to any computer with QEMU and start
them there. `make dbg-vars` shows the kernel command line (`-append`) of your
configuration.

- Base image (`defconfig`): copy the bzImage and the initramfs
```shell
qemu-system-x86_64 -m 16 -no-reboot \
  -kernel smallham-base-x86_64-bzImage \
  -initrd smallham-base-x86_64-initramfs.cpio.xz \
  -append "notsc"
```
- Ham radio setup (`ham_defconfig`, persistent disk): copy also the disk image
```shell
qemu-system-x86_64 -m 32 -no-reboot \
  -kernel smallham-ham-x86_64-bzImage \
  -initrd smallham-ham-x86_64-initramfs.cpio.xz \
  -drive file=smallham-ham-x86_64-disk.img,format=raw,if=virtio \
  -append "notsc squashfs_dev=/dev/vda1 rw_dev=/dev/vda2" \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0
```
- Serial console: add `console=ttyS0` to `-append` and `-nographic` to QEMU
- ISO (`ham_vbox_defconfig`): the kernel command line is inside the ISO.
  `-boot d` is needed, because the disk has no boot loader.
```shell
qemu-system-x86_64 -m 32 -no-reboot -boot d -cdrom smallham-ham-vbox-x86_64.iso \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=smallham-ham-vbox-x86_64-disk.img,format=raw,if=none,id=disk0 \
  -device scsi-hd,drive=disk0,bus=scsi0.0 \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0
```
  (For the base image only `-cdrom smallham-base-vbox-x86_64.iso` is needed.)

### Run with VirtualBox
Load a VirtualBox configuration (or select `Target platform: VirtualBox (ISO)`
in `make menuconfig`), then make the ISO:
```shell
make ham_vbox_defconfig     # or: make base_vbox_defconfig
make iso
```
Output in `build/out/`:

| File (example: `ham_vbox_defconfig`) | What it is |
|---|---|
| `smallham-ham-vbox-x86_64.iso` | bootable CD image with the kernel and the initramfs |
| `smallham-ham-vbox-x86_64-disk.vmdk` | the persistent disk in VirtualBox format (only with `Persistent disk`) |

Copy these files to any computer with VirtualBox and set up a VM:
- Type: Linux, 64-bit. Memory: 16 MB for the base image, 32 MB for the ham radio setup
- Optical drive (IDE): the `.iso` file, boot from it
- Persistent disk: add a **VirtIO SCSI** storage controller and attach the `.vmdk` file to it
- Network: adapter type **Paravirtualized Network (virtio-net)**

The same from the command line:
```shell
VBoxManage createvm --name smallham --ostype Linux_64 --register
VBoxManage modifyvm smallham --memory 32 --boot1 dvd --boot2 disk --nic1 nat --nictype1 virtio --graphicscontroller vboxvga --audio-enabled off
VBoxManage storagectl smallham --name IDE --add ide
VBoxManage storagectl smallham --name VSCSI --add virtio-scsi
VBoxManage storageattach smallham --storagectl IDE --port 1 --device 0 --type dvddrive --medium smallham-ham-vbox-x86_64.iso
VBoxManage storageattach smallham --storagectl VSCSI --port 0 --device 0 --type hdd --medium smallham-ham-vbox-x86_64-disk.vmdk
VBoxManage startvm smallham
```

### Bridged network (host setup)
With a bridge the VM can be reached from your computer and your local network.
Run these commands on your computer as root.

- Create the virbr0 bridge
```shell
ip link add name virbr0 type bridge
ip addr add 192.168.122.1/24 dev virbr0
ip link set virbr0 up
ethtool -K virbr0 tx off rx off
#ip addr show virbr0
```
- Allow QEMU to use the bridge
```shell
echo "allow virbr0" >> /etc/qemu/bridge.conf
```
- DHCP with dnsmasq (`port=5353` turns off its DNS part; the VM gets public DNS servers)
```shell
# vim /etc/dnsmasq.conf
port=5353
interface=virbr0
bind-interfaces
listen-address=192.168.122.1
dhcp-range=192.168.122.100,192.168.122.150,12h
dhcp-option=3,192.168.122.1
dhcp-option=6,8.8.8.8,8.8.4.4
```
- Iptables (`${interface}` is your computer's network interface to the internet, e.g. `eth0`)
```shell
iptables -A INPUT -i virbr0 -j ACCEPT
iptables -A OUTPUT -o virbr0 -j ACCEPT

iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i virbr0 -o ${interface} -j ACCEPT
iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
```
- Turn on forwarding
```shell
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```
- Start QEMU with the bridge (persistent disk)
```shell
qemu-system-x86_64 -m 32 -no-reboot \
  -kernel build/out/smallham-ham-x86_64-bzImage \
  -initrd build/out/smallham-ham-x86_64-initramfs.cpio.xz \
  -drive file=build/out/smallham-ham-x86_64-disk.img,format=raw,if=virtio \
  -append "notsc squashfs_dev=/dev/vda1 rw_dev=/dev/vda2" \
  -device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902 \
  -netdev bridge,id=net0,br=virbr0 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:56
```

## Using the system
There are no users: everything runs as root. This is why Dire Wolf shows a
warning at start. The commands below need the options in brackets
(`make menuconfig`).

### Network (`NET`)
The network starts at boot from `/etc/network/interfaces` (`eth0` with DHCP).
To set it by hand:
```shell
ip link set eth0 up
udhcpc -i eth0
# or a fixed address:
ip addr add 10.0.2.15/24 dev eth0
ip route add default via 10.0.2.2
```

### Sound card (`SOUND`)
```shell
ls -la /sys/class/sound/
cat /proc/asound/cards
lsusb
```
For a test without a real sound card, QEMU can emulate a USB speaker (output only):
```shell
make run QEMU_EXTRA="-audiodev none,id=snd0 -device qemu-xhci -device usb-audio,audiodev=snd0"
```

### AX.25 over KISS with Dire Wolf (`HAM`, `DIREWOLF`, `AX25_TOOLS_KISS`)
Dire Wolf is the sound card modem. With `-p` it gives a virtual KISS TNC on a
pseudo terminal (link: `/tmp/kisstnc`). `kissattach` connects it to an AX.25
network interface (`ax0`).
- AX.25 port (or turn on `AX25_DEFAULT_CONFIG`). Use your own callsign instead of N0CALL.
```shell
mkdir -p /usr/etc/ax25
echo "radio N0CALL-1 9600 255 2 KISS" > /usr/etc/ax25/axports
```
- Dire Wolf configuration (or turn on `DIREWOLF_DEFAULT_CONFIG`)
```shell
echo "ADEVICE plughw:0,0" > /etc/direwolf.conf
```
- Start
```shell
direwolf -t 0 -p -c /etc/direwolf.conf > /tmp/direwolf.log 2>&1 &
kissattach /tmp/kisstnc radio 10.1.1.1
kissparms -c 1 -p radio     # CRC off: Dire Wolf expects plain KISS
ip addr show ax0
```
`-t 0` turns off the colors. Without `kissparms -c 1` Dire Wolf says
"Invalid transmit channel" for the frames of the Linux KISS driver.

### Look into the disk image
Without root, on your computer (the numbers are for the default partition
sizes, see `sfdisk -l <disk image>`):
```shell
cd build/out
dd if=smallham-ham-x86_64-disk.img of=/tmp/rootfs.sqfs bs=512 skip=2048 count=12288
unsquashfs -ls /tmp/rootfs.sqfs                  # read-only root
dd if=smallham-ham-x86_64-disk.img of=/tmp/rw.ext2 bs=512 skip=14336
debugfs -R "ls -l /rw_root" /tmp/rw.ext2         # your changes
```
With root:
```shell
sudo losetup -fP build/out/smallham-ham-x86_64-disk.img
#losetup -a
#lsblk
sudo mkdir -p /mnt/ro /mnt/rw
sudo mount -o ro /dev/loop0p1 /mnt/ro   # squashfs (read-only root)
sudo mount /dev/loop0p2 /mnt/rw         # ext2 (your changes: rw_root/)
```

## Project layout
| Path | Content |
|---|---|
| `Kconfig`, `configs/*_defconfig` | feature selection |
| `configs/kernel/`, `configs/busybox/` | config files of the features |
| `rootfs/` | root filesystem files (`base`, `network`, ...) |
| `fs_init/` | small init program for the persistent disk (mounts squashfs + overlay) |
| `packages/` | extra programs (musl, AX.25, Dire Wolf, ALSA, ...) |
| `patches/` | patches for the programs |
| `scripts/` | helper scripts for the config files |
| `build/out/` | output files: kernel, initramfs, disk image, ISO |
| `sources/`, `toolchain/`, `build/` | downloaded sources, libraries, build output (not in git) |

### Under Construction

#### Package manager 
- Kiss package manager
```shell
git clone https://github.com/kisslinux/kiss.git
```
- TinyGCC
https://bellard.org/tcc/


# TODO's
- 32-bit (i386) version. On x86_64 the kernel parts are placed on 2 MB borders,
  so about 4 MB of RAM is empty space while the system starts. A 32-bit kernel
  does not need this, and its code and data are smaller. The system could start
  with about half the RAM, and it would also run on old 32-bit PCs. For this,
  musl, BusyBox and all programs must be built for 32-bit too.
- Bootchart optimalization
- Testing all drivers
- Testing direwolf communication
- Testing netrom routing
- Testing digirig connection with direwolf
- Testing another linux (tested only Arch linux)
