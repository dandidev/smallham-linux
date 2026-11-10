# SmallHam minimal linux – Educational System-Building Project

This project aims to create a minimal Linux system primarily for learning purposes. The goal is to gain a deep understanding of how a Linux-based system is constructed from the ground up, and how to assemble a working distribution using a modular approach with the Linux kernel, BusyBox, and optional components.
## Key Objectives:
- Practice compiling and configuring the Linux kernel
- Understand initramfs and kernel module handling
- Build a custom init system and boot process
- Integrate core utilities using BusyBox
- Configure the distribution using Kconfig and Makefiles
- Produce a bootable disk image for QEMU
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
sudo pacman -S base-devel bc cpio rsync squashfs-tools e2fsprogs util-linux qemu-system-x86 kconfig-frontends
```
No root access is needed for the build.

#### Clone this project
```shell
git clone https://github.com/dandidev/small-linux.git
```

### Build mini linux
- Select modules
```shell
make menuconfig
```
- Create distro (`disk.img` + `build/initramfs.cpio`)
```shell
make distro
```

Disk layout of `disk.img`:

| Partition | Content | Mounted as |
|---|---|---|
| `vda1` | squashfs (xz), read-only root | overlay lower layer |
| `vda2` | ext2, writable | overlay upper layer (persistent changes) |

Note: `make distro` rebuilds `disk.img`, which wipes the writable partition.

### Run with Qemu
```shell
make run                      # builds disk.img first if it does not exist
make run QEMU_MEM=20          # change RAM size (MB)
make run QEMU_EXTRA="-device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902"
```
`make run` does not rebuild an existing `disk.img`, so the writable partition is kept.
With `NET` enabled QEMU user mode networking is used (`udhcpc` gets `10.0.2.15`).

To leave the system type `reboot`: QEMU runs with `-no-reboot`, so it exits
instead of restarting. (`poweroff` cannot switch off the VM, the kernel has no ACPI.)

- Run manually with bridged network
```
qemu-system-x86_64 -m 30 -no-reboot \
  -kernel build/kernel/arch/x86/boot/bzImage \
  -initrd build/initramfs.cpio \
  -drive file=disk.img,format=raw,if=virtio \
  -append "notsc squashfs_dev=/dev/vda1 rw_dev=/dev/vda2" \
  -device qemu-xhci -device usb-host,vendorid=0x08bb,productid=0x2902 \
  -netdev bridge,id=net0,br=virbr0 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:56
```

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
- Bootchart optimalization
- Fix poweroff (needs ACPI; until then use `reboot`, QEMU exits because of `-no-reboot`)
- Config module size optimalization
- USB modules->kernel/fs/nls/nls_base.ko->utf16s_to_utf8s() thinking
- Testing all module
- Testing direwolf communication
- Testing netrom routing
- Testing digirig connection with direwolf
- Testing another linux (tested only Arch linux)