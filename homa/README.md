# Two Homa test VMs on one network

[Homa](https://github.com/PlatformLab/HomaModule) is a low latency RPC
transport protocol. This directory starts two SmallHam virtual machines on
one network, so they can talk to each other with Homa.

The image is the normal Homa image: there is no network setting in it, the
VMs ask for their IP address with DHCP on `eth0`. The environment is on your
computer:

| File | What it is |
|---|---|
| `homa.env` | image files, RAM, the disk copies, the bridge, the MAC addresses |
| `start-vm.sh` | starts VM 1 or VM 2 with these settings |

## 1. Network on your computer
A bridge (`virbr0`) with a DHCP server (dnsmasq) on it. Follow
"Bridged network (host setup)" in the [main README](../README.md) (needs
root). The bridge is lost on reboot: create it again and start dnsmasq.
```shell
ip link show virbr0             # the bridge exists
systemctl status dnsmasq        # the DHCP server runs
```

## 2. Build the image
```shell
make homa_defconfig     # profile "Homa test system": kernel 6.17, Homa, persistent disk
make
```

## 3. Start the two VMs
Each VM in its own terminal, in any order:
```shell
homa/start-vm.sh 1      # terminal 1
homa/start-vm.sh 2      # terminal 2
```
Type `reboot` in a VM to leave it.

Both VMs are connected to `virbr0` (QEMU `-netdev bridge`, with the MAC
address from `homa.env`) and get an address from dnsmasq
(192.168.122.100-150). The address of a VM:
```shell
ip addr show eth0
```

## 4. Test Homa
In VM 1:
```shell
server &                                                  # Homa echo server on port 4000
```
In VM 2, with the address of VM 1:
```shell
ping -c 3 <VM 1 address>
homa_test <VM 1 address>:4000 rtt                               # 1000 RPCs of 100 bytes
homa_test <VM 1 address>:4000 --length 100000 --count 100 rtt   # 100 KB messages
```
`homa_test` prints the round trip times (min, median, max). `lsmod` shows the
module, `/proc/sys/net/homa/` its settings and `/proc/net/homa_metrics` its
counters.

If `ping` works but `homa_test` does not, check the firewall of your
computer: the bridge may block packets that are not TCP or UDP (Homa is IP
protocol 146).

## Disks
Two VMs cannot write the same disk image, so each one gets a copy:
`build/homa-vms/vm1-disk.img` and `vm2-disk.img`. They are made from
`build/out/smallham-homa-x86_64-disk.img` the first time a VM starts. The
files you put on them are kept. After `make` builds a new image, the script
tells you; delete the copy to use the new system (your files on it are lost).

## Change the environment
Edit `homa.env`, e.g. `HOMA_MEM` for more RAM, or another bridge. The kernel
command line (`HOMA_CMDLINE`) must match the image: QEMU platform,
persistent disk and serial console, as `make homa_defconfig` sets them.
