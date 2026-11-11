# SmallHam minimal linux – Educational System-Building Project

This project aims to create a minimal Linux system primarily for learning purposes. The goal is to gain a deep understanding of how a Linux-based system is constructed from the ground up, and how to assemble a working distribution using a modular approach with the Linux kernel, BusyBox, and optional components.
## Key Objectives:
- Practice compiling and configuring the Linux kernel
- Understand initramfs and the boot process
- Build a custom init system and boot process
- Integrate core utilities using BusyBox
- Configure the distribution using Kconfig and Makefiles
- Produce a bootable disk image for QEMU
- **Enable amateur radio control testing on minimal hardware**

## Amateur Radio Support

This project includes amateur radio kernel drivers (e.g., AX.25, MKISS, 6PACK, NET/ROM, ROSE), offering functionality tailored for the amateur radio community. One of the key objectives was to enable running the system on minimal hardware, making it suitable for simulating repeater stations or radio tower emulation on general-purpose computers.


## Configuration (menuconfig)

The base image contains nothing but the kernel and a BusyBox shell in an
initramfs. Every feature is added with `make menuconfig`:

```shell
make defconfig       # base image (default when there is no .config)
make ham_defconfig   # ham radio setup: disk, network, USB sound, AX.25, direwolf
make menuconfig      # add/remove features
make savedefconfig   # write the current selection to ./defconfig
```

How the options are applied:

| What | Where | How |
|---|---|---|
| Kernel | `configs/kernel/*.config` | `allnoconfig` + the fragments of the selected options, all drivers built in (no modules) |
| BusyBox | `configs/busybox/*.config` | `allnoconfig` + the fragments of the selected options |
| Root filesystem | `rootfs/<name>/` | copied over each other (`base` always) |
| Programs | `packages/*.mk` | built and copied to `/usr/bin` |

`scripts/check-config.sh` stops the build if an option of a fragment did not get
into the final config (misspelled name or missing dependency).

#### System
- **Target platform**: `QEMU` (disk: virtio-blk, `/dev/vda`) or `VirtualBox (ISO)` (disk: VirtIO SCSI, `/dev/sda`)
- **Root filesystem**:
  - `initramfs only`: the whole system is in RAM, changes are lost on reboot
  - `Persistent disk`: read-only squashfs + writable ext2 combined with overlayfs (`fs_init`)
- **Console**: VGA + PS/2 keyboard, or serial (`ttyS0`, QEMU runs with `-nographic`)
- **ACPI**: `poweroff` switches off the VM (without it use `reboot`)

#### Kernel drivers
- `NET` – virtio-net, IPv4, DHCP (`ifup`, `udhcpc`)
- `USB` – xHCI/EHCI host controllers (for passed through USB devices)
- `USB_STORAGE` – USB mass storage with FAT filesystem
- `SOUND` – USB sound cards (ALSA)
- `HAM` – AX.25, NET/ROM, ROSE, MKISS (KISS), 6PACK, BPQ, Baycom, YAM

#### Userspace
- `BB_TOOLS` – grep, sed, find, head, tail, less, top, ...
- `BB_EDITOR` – vi
- `BB_SYSLOG` – syslogd, logread

#### Extras
- AX.25 tools (`kissattach`, `kissparms`, `netromd`), AX.25 apps (`call`, `listen`, `ax25ipd`), Dire Wolf, `aplay`
- Optional default configs: `/usr/etc/ax25/axports`, `/etc/direwolf.conf`

## Getting started
### Prerequisites 
#### Packages
```shell
sudo pacman -S base-devel bc cpio rsync squashfs-tools e2fsprogs util-linux qemu-system-x86 kconfig-frontends
# for VirtualBox ISO:
sudo pacman -S syslinux cdrtools
```
No root access is needed for the build. About 2.5 GB free space is needed
(mostly the kernel source).

#### Clone this project
```shell
git clone https://github.com/dandidev/small-linux.git
```

### Build mini linux
```shell
make menuconfig
make
```
Output:
- `build/kernel/arch/x86/boot/bzImage`
- `build/initramfs.cpio.xz`
- `disk.img` (only with `Persistent disk`)

Disk layout of `disk.img`:

| Partition | Content | Mounted as |
|---|---|---|
| `vda1` | squashfs (xz), read-only root | overlay lower layer |
| `vda2` | ext2, writable | overlay upper layer (persistent changes) |

Note: `make` rebuilds `disk.img`, which wipes the writable partition.

### Run with Qemu
```shell
make run                      # builds the images first if they do not exist
make run QEMU_MEM=20          # change RAM size (MB)
make run QEMU_EXTRA="-device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902"
```
`make run` does not rebuild an existing `disk.img`, so the writable partition is kept.
With `NET` enabled QEMU user mode networking is used (`udhcpc` gets `10.0.2.15`).

To leave the system type `reboot`: QEMU runs with `-no-reboot`, so it exits
instead of restarting. With the ACPI option `poweroff` works too.
With the serial console leave QEMU with `Ctrl-A X`.

- Run manually with bridged network (persistent disk)
```
qemu-system-x86_64 -m 30 -no-reboot \
  -kernel build/kernel/arch/x86/boot/bzImage \
  -initrd build/initramfs.cpio.xz \
  -drive file=disk.img,format=raw,if=virtio \
  -append "notsc squashfs_dev=/dev/vda1 rw_dev=/dev/vda2" \
  -device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902 \
  -netdev bridge,id=net0,br=virbr0 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:56
```

### Run with VirtualBox
Select `Target platform: VirtualBox (ISO)` in `make menuconfig`, then:
```shell
make iso      # build/smallham.iso (+ build/disk.vmdk with the persistent disk)
```
VM settings:
- Type: Linux, 64-bit; memory: 32 MB is enough
- Optical drive (IDE): `build/smallham.iso`, boot from it
- Persistent disk: add a **VirtIO SCSI** storage controller and attach `build/disk.vmdk` to it
- Network: adapter type **Paravirtualized Network (virtio-net)**

### How to

#### Create virtbr0 bridge to qemu network
```shell
ip link add name virbr0 type bridge
ip addr add 192.168.122.1/24 dev virbr0
ip link set virbr0 up
ethtool -K virbr0 tx off rx off
#ip addr show virbr0
```
##### DHCP dnsmasq configuration
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
##### Iptables
```shell
iptables -A INPUT -i virbr0 -j ACCEPT
iptables -A OUTPUT -o virbr0 -j ACCEPT

iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i virbr0 -o ${interface} -j ACCEPT
iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
```
##### Forward enable
```shell
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

#### Direwolf
- Configuration
```shell
echo "ADEVICE plughw:0,0" > /etc/direwolf.conf
```
- Run
```shell
direwolf -f 0 -c /etc/direwolf.conf
```

#### .img mount
```shell
sudo losetup -fP disk.img
#losetup -a
#lsblk
sudo mount -o ro /dev/loop0p1 /mnt   # squashfs (read-only root)
sudo mount /dev/loop0p2 /mnt         # ext2 (overlay upper layer: rw_root/)
```
#### Linux commands
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
- Bootchart optimalization
- Testing all drivers
- Testing direwolf communication
- Testing netrom routing
- Testing digirig connection with direwolf
- Testing another linux (tested only Arch linux)