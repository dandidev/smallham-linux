# Changelog

## Unreleased

- Fix: the writable ext2 partition of the persistent disk was never
  unmounted cleanly ("EXT2-fs: mounting unchecked fs" at every boot). It
  stayed mounted in the initramfs, out of reach after switch_root. Now
  `fs_init` moves both layers into the new root (`/mnt/ro`, `/mnt/rw`), and
  the new `/etc/init.d/rcK` (inittab `::shutdown`) stops the programs and
  remounts `/mnt/rw` read-only before reboot or poweroff.

## v0.7 – VirtualBox appliance and more drivers

- More drivers can be selected in "Kernel drivers": disk controllers
  (VirtIO block, VirtIO SCSI, SATA/AHCI) and network cards (virtio-net,
  Intel PRO/1000). The platform still turns on only one of each.
  AHCI and PRO/1000 are the defaults of a new VirtualBox VM.
- `fs_init` finds the persistent disk by its content (squashfs + ext2
  partition), so it works on every disk controller; the kernel command line
  has no device names any more. It waits up to 10 seconds for slow devices.
  If no disk is found, it lists the block devices and the disk drivers of
  the kernel, with a hint.
- `make ova` makes a VirtualBox appliance (`.ova`) with a persistent
  disk: importing it creates a VM with the right storage controller and
  network card, with the ISO and the disk attached. It is a new release file
  for the VirtualBox ham radio setup.
- README: step by step VirtualBox setup by hand, also for the case when the
  disk is on the SATA controller of a new VM.
- The ISO (and so the `.ova`) has the license texts in `licenses/`, like
  the other release files. The ISO has Rock Ridge and Joliet names.
- The sources archive has the whole Dire Wolf source again, with its
  `doc/` folder of PDF manuals (v0.6 left it out).

## v0.6 – first release with downloadable files

- Release files: QEMU packages with a `run.sh` (base on initramfs, base on a
  persistent disk, ham radio setup), a VirtualBox ISO (base) and a VirtualBox
  ISO + `.vmdk` (ham radio setup), the source code (the kernel source as a
  separate file) and `SHA256SUMS` (`make release`).
- New output file names: the root filesystem type is part of the name
  (`base-initramfs`, `base-squashfs`, `ham-squashfs`, with `-vbox` for
  VirtualBox).
- `base_squashfs_defconfig`: the base system on a persistent disk.
- The squashfs root filesystem is also kept as a separate file
  (`...-rootfs.squashfs`).
- `/etc/os-release` with the version.
- The AX.25 packages (libax25, ax25-tools, ax25-apps) are built from fixed
  commits.
- Configuration profiles in menuconfig: None, Persistent system, Ham radio
  station.
- License (GPL-2.0), ROADMAP.md and a new README introduction.

## v0.5 – 2026-11-11

- Every feature can be selected in Kconfig (`make menuconfig`); the kernel
  and BusyBox are built from small config fragments.
- BusyBox and all packages are built statically with musl instead of glibc.
- Smaller kernel and BusyBox: the base system boots with 16 MB RAM.
- The architecture and the image name are in the output file names.
- Fixes for `make run`, Dire Wolf start and low memory boot.

## v0.4 – 2025-06-01

- Persistent disk: read-only squashfs root with a writable ext2 overlay
  (`fs_init`).
- Packages are in separate makefiles (`packages/*.mk`).
- `aplay` (alsa-utils) and `ax25ipd`.
- VirtualBox ISO fixes.

## v0.3 – 2025-05-11

- Extra packages (AX.25 tools and apps, Dire Wolf) built by the Makefile.

## v0.2 – 2025-05-04

- Kernel support for USB, sound cards, disks and overlayfs; AX.25 modules.
- Network support.
- Bootable ISO.
- New folder structure and a distro builder in the Makefile.

## v0.1 – 2025-04-29

- First version: kernel, BusyBox init with inittab, network, ISO build
  steps.
