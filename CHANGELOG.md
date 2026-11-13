# Changelog

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
