# Roadmap

Planned work and open questions. Nothing here is done yet.

## Testing
- Communication between two stations with Dire Wolf
- NET/ROM routing
- Digirig (USB sound card + PTT) with Dire Wolf
- All kernel drivers in the configuration
- Building on other Linux distributions (only Arch Linux is tested)

## Features
- 32-bit (i386) version. On x86_64 the kernel parts are placed on 2 MB borders,
  so about 4 MB of RAM is empty space while the system starts. A 32-bit kernel
  does not need this, and its code and data are smaller. The system could start
  with about half the RAM, and it would also run on old 32-bit PCs. For this,
  musl, BusyBox and all programs must be built for 32-bit too.
- **[Homa](https://github.com/PlatformLab/HomaModule) transport protocol
  (experimental, under development)** on the branch
  [`feature/homa-experimental`](https://github.com/dandidev/smallham-linux/tree/feature/homa-experimental).
  It is not part of `master`.
- Package manager, for example the
  [KISS package manager](https://github.com/kisslinux/kiss), and a small C
  compiler in the system: [TCC (Tiny C Compiler)](https://bellard.org/tcc/).

## Optimization
- Faster boot: measure it with bootchart and remove the slow parts.

## Homa (branch `feature/homa-experimental`)
The Homa image is for functional tests, development and learning, not for
performance measurements. Open work:
- Test `homa/start-vm.sh` on the `virbr0` bridge again. After the rebase onto
  v0.7 the two VMs were only tested on a QEMU socket network.
- A short guide for learning: what `homa_test`, `cp_node` and
  `/proc/net/homa_metrics` show, with a few exercises.
- Kernel clock: the VMs use refined-jiffies (`notsc`, no HPET), 4 ms
  resolution. Try kvmclock (`KVM_GUEST`, `PARAVIRT`) or remove `notsc`.
- More than two VMs (e.g. a small `cp_node` cluster) for functional tests.
- The test programs are linked statically with glibc (C++), so they cannot go
  into release files. Build them with musl and a C++ library for musl.
- Later, real hardware: a driver for the network card, SMP and an exact
  clock; boot with PXE or from USB.
