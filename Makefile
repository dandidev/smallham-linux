# SmallHam build system
#
#   make defconfig       base image: kernel + initramfs with a BusyBox shell
#   make ham_defconfig   ham radio setup (disk, network, sound, AX.25, direwolf)
#   make menuconfig      select features
#   make                 build (kernel, initramfs and disk.img if selected)
#   make run             boot in QEMU
#   make iso             VirtualBox ISO (+ .vmdk)

KCONFIG_FILE := Kconfig
.DEFAULT_GOAL := all

# Without a .config start from the base image configuration.
.config:
	kconfig-conf --defconfig=configs/defconfig $(KCONFIG_FILE)

include .config

# --------------------------------------------------------------------

ROOT := $(CURDIR)
SOURCES := $(ROOT)/sources
BUILD := $(ROOT)/build
PREFIX := $(ROOT)/toolchain
STAMP := $(BUILD)/stamps

$(shell mkdir -p $(SOURCES) $(BUILD) $(PREFIX) $(STAMP))

# --------------------------------------------------------------------

KERNEL_VERSION := 6.6.162
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL_TARBALL)
KERNEL_SRC := $(SOURCES)/linux-$(KERNEL_VERSION)
KERNEL_BUILD := $(BUILD)/kernel
KERNEL_PREPARED := $(STAMP)/kernel-$(KERNEL_VERSION).prepared
KERNEL_CONFIGURED := $(STAMP)/kernel-$(KERNEL_VERSION).configured
KERNEL_FRAGMENT := $(BUILD)/kernel.fragment
BZIMAGE := $(KERNEL_BUILD)/arch/x86/boot/bzImage

LINUX_HEADERS_DIR := $(PREFIX)/linux-headers
LINUX_HEADERS_INSTALLED := $(STAMP)/linux-headers-$(KERNEL_VERSION).installed

BUSYBOX_VERSION := 1.37.0
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_SRC := $(SOURCES)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD := $(BUILD)/busybox
BUSYBOX_FRAGMENT := $(BUILD)/busybox.fragment

ROOTFS_DIR := $(BUILD)/rootfs
INITRAMFS := $(BUILD)/initramfs.cpio.xz
INITRAMFS_LIST := $(BUILD)/initramfs.list
# Small dictionary: the kernel allocates the whole dictionary while unpacking
# (xz -9 would need 64 MiB RAM).
XZ_INITRAMFS := xz --check=crc32 --lzma2=preset=9e,dict=1MiB

IMG := $(ROOT)/disk.img
DISK_SIZE_MB := 8
SQUASHFS_SIZE_MB := 6
SQUASHFS_IMG := $(BUILD)/squashfs.img
RW_IMG := $(BUILD)/rw.img

# Partition layout (512 byte sectors)
SQUASHFS_START := 2048
SQUASHFS_SECTORS := $(shell echo $$(($(SQUASHFS_SIZE_MB) * 2048)))
RW_START := $(shell echo $$(($(SQUASHFS_START) + $(SQUASHFS_SECTORS))))
RW_SECTORS := $(shell echo $$(($(DISK_SIZE_MB) * 2048 - $(RW_START))))

ISO_DIR := $(BUILD)/iso
ISO_IMG := $(BUILD)/smallham.iso
VMDK := $(BUILD)/disk.vmdk

# --------------------------------------------------------------------
# Feature selection: .config -> kernel/BusyBox config fragments, rootfs
# overlays and kernel command line.

KERNEL_FRAGMENTS := base
BUSYBOX_FRAGMENTS := base
ROOTFS_OVERLAYS := base
KERNEL_CMDLINE := notsc
QEMU_ARGS :=

ifeq ($(CONFIG_PLATFORM_VBOX),y)
DISK_DEV := sda
DISK_KERNEL_FRAGMENT := disk-virtio-scsi
QEMU_DISK = -device virtio-scsi-pci,id=scsi0 -drive file=$(IMG),format=raw,if=none,id=disk0 \
            -device scsi-hd,drive=disk0,bus=scsi0.0
else
DISK_DEV := vda
DISK_KERNEL_FRAGMENT := disk-virtio-blk
QEMU_DISK = -drive file=$(IMG),format=raw,if=virtio
endif

ifeq ($(CONFIG_CONSOLE_SERIAL),y)
KERNEL_FRAGMENTS += console-serial
CONSOLE_TTY := ttyS0
KERNEL_CMDLINE += console=ttyS0
QEMU_ARGS += -nographic
else
KERNEL_FRAGMENTS += console-vga
CONSOLE_TTY := tty1
endif

ifeq ($(CONFIG_ROOTFS_DISK),y)
KERNEL_FRAGMENTS += rootfs-disk virtio $(DISK_KERNEL_FRAGMENT)
BUSYBOX_FRAGMENTS += disk
KERNEL_CMDLINE += squashfs_dev=/dev/$(DISK_DEV)1 rw_dev=/dev/$(DISK_DEV)2
QEMU_ARGS += $(QEMU_DISK)
NEED_VIRTIO := y
endif

ifeq ($(CONFIG_NET),y)
KERNEL_FRAGMENTS += net virtio
BUSYBOX_FRAGMENTS += net
ROOTFS_OVERLAYS += network
QEMU_ARGS += -netdev user,id=net0 -device virtio-net-pci,netdev=net0
NEED_VIRTIO := y
endif

ifeq ($(CONFIG_PLATFORM_VBOX)$(NEED_VIRTIO),yy)
KERNEL_FRAGMENTS += virtio-legacy
endif

ifeq ($(CONFIG_ACPI_POWEROFF),y)
KERNEL_FRAGMENTS += acpi
endif

ifeq ($(CONFIG_USB),y)
KERNEL_FRAGMENTS += usb
BUSYBOX_FRAGMENTS += usb
endif

ifeq ($(CONFIG_USB_STORAGE),y)
KERNEL_FRAGMENTS += usb-storage
endif

ifeq ($(CONFIG_SOUND),y)
KERNEL_FRAGMENTS += sound
endif

ifeq ($(CONFIG_HAM),y)
KERNEL_FRAGMENTS += ham
endif

ifeq ($(CONFIG_BB_TOOLS),y)
BUSYBOX_FRAGMENTS += tools
endif

ifeq ($(CONFIG_BB_EDITOR),y)
BUSYBOX_FRAGMENTS += editor
endif

ifeq ($(CONFIG_BB_SYSLOG),y)
KERNEL_FRAGMENTS += syslog
BUSYBOX_FRAGMENTS += syslog
endif

ifeq ($(CONFIG_AX25_DEFAULT_CONFIG),y)
ROOTFS_OVERLAYS += ax25
endif

ifeq ($(CONFIG_DIREWOLF_DEFAULT_CONFIG),y)
ROOTFS_OVERLAYS += direwolf
endif

KERNEL_FRAGMENT_FILES := $(patsubst %,configs/kernel/%.config,$(sort $(KERNEL_FRAGMENTS)))
BUSYBOX_FRAGMENT_FILES := $(patsubst %,configs/busybox/%.config,$(sort $(BUSYBOX_FRAGMENTS)))

# --------------------------------------------------------------------
# Extra packages (packages/*.mk)

include $(wildcard packages/*.mk)

BUILD_PKGS :=
RUNTIME_BINS :=

_delim := |
_split = $(word $(1),$(subst $(_delim), ,$(2)))

define ProcessFeature
$(if $(CONFIG_$(call _split,1,$(1))),\
     $(eval BUILD_PKGS += $(call _split,2,$(1))))
endef

define ProcessBin
$(if $(CONFIG_$(call _split,1,$(1))),\
     $(eval RUNTIME_BINS += $(call _split,2,$(1))))
endef

$(foreach f,$(PKG_FEATURES), $(call ProcessFeature,$f))
$(foreach b,$(PKG_BINS), $(call ProcessBin,$b))

BUILD_PKGS   := $(sort $(BUILD_PKGS))
RUNTIME_BINS := $(sort $(RUNTIME_BINS))

# --------------------------------------------------------------------

.PHONY: all distro kernel kernel-headers busybox rootfs initramfs fs-init extras \
        run iso menuconfig defconfig oldconfig savedefconfig \
        clean clean-distro dbg-vars FORCE

all: distro

ifeq ($(CONFIG_ROOTFS_DISK),y)
distro: kernel initramfs $(IMG)
else
distro: kernel initramfs
endif

clean-distro:
	rm -rf $(ROOTFS_DIR) $(INITRAMFS) $(ISO_DIR) $(ISO_IMG) $(VMDK)

extras: $(BUILD_PKGS)

dbg-vars:
	@echo "KERNEL_FRAGMENTS  = $(KERNEL_FRAGMENT_FILES)"
	@echo "BUSYBOX_FRAGMENTS = $(BUSYBOX_FRAGMENT_FILES)"
	@echo "ROOTFS_OVERLAYS   = $(ROOTFS_OVERLAYS)"
	@echo "KERNEL_CMDLINE    = $(KERNEL_CMDLINE)"
	@echo "BUILD_PKGS        = $(BUILD_PKGS)"
	@echo "RUNTIME_BINS      = $(RUNTIME_BINS)"

# --------------------------------------------------------------------
# Configuration (kconfig-frontends)

menuconfig:
	kconfig-mconf $(KCONFIG_FILE)

defconfig:
	kconfig-conf --defconfig=configs/defconfig $(KCONFIG_FILE)

%_defconfig:
	kconfig-conf --defconfig=configs/$@ $(KCONFIG_FILE)

oldconfig:
	kconfig-conf --olddefconfig $(KCONFIG_FILE)

savedefconfig:
	kconfig-conf --savedefconfig=defconfig $(KCONFIG_FILE)
	@echo "Saved to ./defconfig"

# Concatenated fragment, rewritten only when its content changes, so the
# kernel/BusyBox is reconfigured only after a feature selection change.
define write_if_changed
	@mkdir -p $(dir $(1))
	@cat $(2) > $(1).tmp
	@if cmp -s $(1).tmp $(1); then rm $(1).tmp; else mv $(1).tmp $(1); fi
endef

$(KERNEL_FRAGMENT): FORCE
	$(call write_if_changed,$@,$(KERNEL_FRAGMENT_FILES))

$(BUSYBOX_FRAGMENT): FORCE
	$(call write_if_changed,$@,$(BUSYBOX_FRAGMENT_FILES))

FORCE:

# --------------------------------------------------------------------
# Kernel: allnoconfig + selected fragments, everything built in

kernel: $(BZIMAGE)

$(KERNEL_PREPARED):
	@mkdir -p $(SOURCES)
	curl -L $(KERNEL_URL) -o $(SOURCES)/$(KERNEL_TARBALL)
	tar -xf $(SOURCES)/$(KERNEL_TARBALL) -C $(SOURCES)
	rm -f $(SOURCES)/$(KERNEL_TARBALL)
	@touch $@

$(KERNEL_CONFIGURED): $(KERNEL_PREPARED) $(KERNEL_FRAGMENT)
	@mkdir -p $(KERNEL_BUILD)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) KCONFIG_ALLCONFIG=$(KERNEL_FRAGMENT) allnoconfig
	scripts/check-config.sh $(KERNEL_FRAGMENT) $(KERNEL_BUILD)/.config
	@touch $@

$(BZIMAGE): $(KERNEL_CONFIGURED) FORCE
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) bzImage

# Separate O= directory: headers_install must not run in $(KERNEL_BUILD)
# in parallel with the kernel build (make -j).
$(LINUX_HEADERS_INSTALLED): $(KERNEL_PREPARED)
	@mkdir -p $(LINUX_HEADERS_DIR)
	$(MAKE) -C $(KERNEL_SRC) O=$(BUILD)/kernel-headers ARCH=x86 \
	        INSTALL_HDR_PATH=$(LINUX_HEADERS_DIR) headers_install
	@touch $@

kernel-headers: $(LINUX_HEADERS_INSTALLED)

# --------------------------------------------------------------------
# BusyBox: allnoconfig + selected fragments (its old kconfig ignores
# KCONFIG_ALLCONFIG in allnoconfig, so the fragment is applied with oldconfig)

busybox: $(BUSYBOX_BUILD)/busybox

$(BUSYBOX_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(BUSYBOX_URL) -o $(SOURCES)/$(BUSYBOX_TARBALL)
	tar -xf $(SOURCES)/$(BUSYBOX_TARBALL) -C $(SOURCES)
	rm -f $(SOURCES)/$(BUSYBOX_TARBALL)
	cd $(BUSYBOX_SRC)/scripts/kconfig/lxdialog && patch -p0 < $(abspath patches/busybox-lxdiagcheck.patch)
	@touch $@

$(BUSYBOX_BUILD)/.config: $(BUSYBOX_FRAGMENT) $(BUSYBOX_SRC)/.prepared
	@mkdir -p $(BUSYBOX_BUILD)
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) allnoconfig
	scripts/apply-fragment.sh $(BUSYBOX_FRAGMENT) $@
	yes "" | $(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) oldconfig > /dev/null
	scripts/check-config.sh $(BUSYBOX_FRAGMENT) $@

$(BUSYBOX_BUILD)/busybox: $(BUSYBOX_BUILD)/.config FORCE
	CFLAGS="-Os -flto" LDFLAGS="-static -flto" \
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD)

# --------------------------------------------------------------------
# Root filesystem (rebuilt from scratch, so disabled features leave nothing behind)

rootfs: busybox extras
	rm -rf $(ROOTFS_DIR)
	mkdir -p $(addprefix $(ROOTFS_DIR)/,bin dev proc sys tmp root var/run var/log)
	for o in $(ROOTFS_OVERLAYS); do cp -a $(ROOT)/rootfs/$$o/. $(ROOTFS_DIR)/; done
	sed -i 's/^@CONSOLE@/$(CONSOLE_TTY)/' $(ROOTFS_DIR)/etc/inittab
	cp $(BUSYBOX_BUILD)/busybox $(ROOTFS_DIR)/bin/busybox
	cd $(ROOTFS_DIR)/bin && for c in $$(./busybox --list); do ln -sf busybox $$c; done
ifneq ($(RUNTIME_BINS),)
	mkdir -p $(ROOTFS_DIR)/usr/bin
	cp $(RUNTIME_BINS) $(ROOTFS_DIR)/usr/bin/
endif
	find $(ROOTFS_DIR) -type f -perm /a+x -print0 | \
	xargs -0 file -i | awk -F: '/application\/x-executable/{print $$1}' | \
	xargs -r strip --strip-all

# --------------------------------------------------------------------
# initramfs (xz compressed; gen_initramfs.sh/gen_init_cpio from the kernel
# create device nodes and root owned files without root privileges)

ifeq ($(CONFIG_ROOTFS_DISK),y)

FS_INIT_SRC := $(ROOT)/fs_init
FS_INIT := $(BUILD)/fs_init/init

fs-init: musl kernel-headers
	@mkdir -p $(dir $(FS_INIT))
	$(MUSL_CC) -Os -static -I$(LINUX_HEADERS_DIR)/include $(FS_INIT_SRC)/fs_init.c -o $(FS_INIT)
	strip --strip-all $(FS_INIT)

# Only fs_init: it mounts the root filesystem from the disk.
initramfs: fs-init kernel
	printf '%s\n' \
	  'dir /dev 0755 0 0' \
	  'nod /dev/console 0600 0 0 c 5 1' \
	  'dir /proc 0555 0 0' \
	  'file /init $(FS_INIT) 0755 0 0' > $(INITRAMFS_LIST)
	$(KERNEL_BUILD)/usr/gen_init_cpio $(INITRAMFS_LIST) | $(XZ_INITRAMFS) > $(INITRAMFS)

else

# The whole system: /init is BusyBox init.
initramfs: rootfs kernel
	printf '%s\n' \
	  'nod /dev/console 0600 0 0 c 5 1' \
	  'slink /init /bin/busybox 0777 0 0' > $(INITRAMFS_LIST)
	cd $(KERNEL_BUILD) && $(KERNEL_SRC)/usr/gen_initramfs.sh -o $(INITRAMFS).cpio \
	  -u $$(id -u) -g $$(id -g) $(ROOTFS_DIR) $(INITRAMFS_LIST)
	$(XZ_INITRAMFS) < $(INITRAMFS).cpio > $(INITRAMFS)
	rm -f $(INITRAMFS).cpio

endif

# --------------------------------------------------------------------
# Disk image: squashfs + ext2, built without root (no losetup/sudo).
# WARNING: rebuilding the image wipes the writable (rw) partition.

$(IMG): rootfs
	rm -f $(IMG) $(SQUASHFS_IMG) $(RW_IMG)
	mksquashfs $(ROOTFS_DIR) $(SQUASHFS_IMG) -noappend -all-root -comp xz -b 256k -quiet
	@size=$$(stat -c %s $(SQUASHFS_IMG)); max=$$(($(SQUASHFS_SECTORS) * 512)); \
	if [ $$size -gt $$max ]; then \
	  echo "ERROR: squashfs ($$size bytes) does not fit into $(SQUASHFS_SIZE_MB) MB partition"; exit 1; \
	fi
	truncate -s $(DISK_SIZE_MB)M $(IMG)
	printf 'label: dos\nunit: sectors\nstart=%s, size=%s, type=83\nstart=%s, size=%s, type=83\n' \
	  $(SQUASHFS_START) $(SQUASHFS_SECTORS) $(RW_START) $(RW_SECTORS) | sfdisk -q $(IMG)
	dd if=$(SQUASHFS_IMG) of=$(IMG) bs=1M seek=$$(($(SQUASHFS_START) * 512)) \
	  oflag=seek_bytes conv=notrunc status=none
	truncate -s $$(($(RW_SECTORS) * 512)) $(RW_IMG)
	mkfs.ext2 -q -F $(RW_IMG)
	dd if=$(RW_IMG) of=$(IMG) bs=1M seek=$$(($(RW_START) * 512)) \
	  oflag=seek_bytes conv=notrunc status=none
	rm -f $(SQUASHFS_IMG) $(RW_IMG)

# --------------------------------------------------------------------
# QEMU

QEMU_MEM ?= 30
QEMU_EXTRA ?=

# Does not rebuild anything if the images exist (data on the rw partition survives).
# -no-reboot: 'reboot' exits QEMU.
run:
	@[ -f $(BZIMAGE) ] && [ -f $(INITRAMFS) ] || $(MAKE) distro
ifeq ($(CONFIG_ROOTFS_DISK),y)
	@[ -f $(IMG) ] || $(MAKE) distro
endif
	qemu-system-x86_64 -m $(QEMU_MEM) -no-reboot \
	    -kernel $(BZIMAGE) -initrd $(INITRAMFS) \
	    -append "$(KERNEL_CMDLINE)" \
	    $(QEMU_ARGS) $(QEMU_EXTRA)

# --------------------------------------------------------------------
# VirtualBox: bootable ISO (isolinux) + .vmdk for the persistent disk

ISOLINUX_DIR ?= /usr/lib/syslinux/bios

ifneq ($(filter iso,$(MAKECMDGOALS)),)
ifneq ($(CONFIG_PLATFORM_VBOX),y)
$(error 'make iso' needs 'Target platform: VirtualBox' (make menuconfig))
endif
endif

iso: distro
	rm -rf $(ISO_DIR)
	mkdir -p $(ISO_DIR)/isolinux
	cp $(BZIMAGE) $(ISO_DIR)/bzImage
	cp $(INITRAMFS) $(ISO_DIR)/initrd.xz
	cp $(ISOLINUX_DIR)/isolinux.bin $(ISOLINUX_DIR)/ldlinux.c32 $(ISO_DIR)/isolinux/
	printf 'DEFAULT linux\nLABEL linux\n    KERNEL /bzImage\n    APPEND initrd=/initrd.xz %s\n' \
	  "$(KERNEL_CMDLINE)" > $(ISO_DIR)/isolinux/isolinux.cfg
	genisoimage -o $(ISO_IMG) -b isolinux/isolinux.bin \
	  -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
	  -boot-info-table -iso-level 3 -quiet $(ISO_DIR)
ifeq ($(CONFIG_ROOTFS_DISK),y)
	rm -f $(VMDK)
	qemu-img convert -f raw -O vmdk $(IMG) $(VMDK)
	@echo "Created $(ISO_IMG) and $(VMDK) (attach it to a VirtIO SCSI controller)"
else
	@echo "Created $(ISO_IMG)"
endif

# --------------------------------------------------------------------

clean: alsa-lib-clean alsa-utils-clean musl-clean ncurses-clean direwolf-clean libudev-zero-clean ax25-apps-clean ax25-tools-clean lib-ax25-clean
	rm -rf $(LINUX_HEADERS_DIR)
	rm -rf $(KERNEL_SRC) $(SOURCES)/$(KERNEL_TARBALL)
	rm -rf $(BUSYBOX_SRC) $(SOURCES)/$(BUSYBOX_TARBALL)
	rm -rf $(BUILD)
