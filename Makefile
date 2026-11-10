include .config

# --------------------------------------------------------------------

ROOT := $(CURDIR)
SOURCES := $(ROOT)/sources
BUILD := $(ROOT)/build
PREFIX := $(ROOT)/toolchain
STAMP := $(BUILD)/stamps
INITROOT := $(BUILD)/initroot

$(shell mkdir -p $(SOURCES))
$(shell mkdir -p $(BUILD))
$(shell mkdir -p $(PREFIX))
$(shell mkdir -p $(STAMP))
# --------------------------------------------------------------------

DISK_SIZE_MB := 8
SQUASHFS_SIZE_MB := 6

IMG := $(ROOT)/disk.img
SQUASHFS_IMG := $(BUILD)/squashfs.img
RW_IMG := $(BUILD)/rw.img
SQUASHFS_DIR := $(BUILD)/rootfs

# Partition layout (512 byte sectors)
SQUASHFS_START := 2048
SQUASHFS_SECTORS := $(shell echo $$(($(SQUASHFS_SIZE_MB) * 2048)))
RW_START := $(shell echo $$(($(SQUASHFS_START) + $(SQUASHFS_SECTORS))))
RW_SECTORS := $(shell echo $$(($(DISK_SIZE_MB) * 2048 - $(RW_START))))

INITRAMFS := $(BUILD)/initramfs.cpio
INITRAMFS_LIST := $(BUILD)/initramfs.list
GEN_INIT_CPIO = $(KERNEL_BUILD)/usr/gen_init_cpio

# --------------------------------------------------------------------

KERNEL_VERSION := 6.6.162
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL_TARBALL)
KERNEL_SRC := $(SOURCES)/linux-$(KERNEL_VERSION)
KERNEL_BUILD := $(BUILD)/kernel
KERNEL_PREPARED := $(STAMP)/kernel-$(KERNEL_VERSION).prepared
KERNEL_CONFIGURED := $(STAMP)/kernel-$(KERNEL_VERSION).configured

LINUX_HEADERS_DIR := $(PREFIX)/linux-headers
LINUX_HEADERS_INSTALLED := $(STAMP)/linux-headers-$(KERNEL_VERSION).installed

BUSYBOX_VERSION := 1.37.0
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_SRC := $(SOURCES)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD := $(BUILD)/busybox

# --------------------------------------------------------------------

include $(wildcard packages/*.mk)

# --------------------------------------------------------------------

DISTRO_MODLISTS :=
BUILD_PKGS  :=
RUNTIME_BINS :=

_delim := |

_split = $(word $(1),$(subst $(_delim), ,$(2)))

define ProcessKernelModules
$(if $(CONFIG_$(call _split,1,$(1))),\
  $(eval DISTRO_MODLISTS += $(call _split,2,$(1))))
endef

define ProcessFeature
$(if $(CONFIG_$(call _split,1,$(1))),\
     $(eval BUILD_PKGS += $(call _split,2,$(1))))
endef

define ProcessBin
$(if $(CONFIG_$(call _split,1,$(1))),\
     $(eval RUNTIME_BINS += $(call _split,2,$(1))))
endef

# --------------------------------------------------------------------

MODMAP += HAM|modules/ham.modlist
MODMAP += HAM|modules/lib.modlist
MODMAP += USB|modules/usb.modlist
MODMAP += USB_STORAGE|modules/usb-storage.modlist
MODMAP += NET|modules/network.modlist
MODMAP += NET|modules/lib.modlist
MODMAP += SOUND|modules/sound.modlist
MODMAP += SOUND|modules/lib.modlist

# --------------------------------------------------------------------

$(foreach m,$(MODMAP), $(call ProcessKernelModules,$(m)))
$(foreach f,$(PKG_FEATURES), $(call ProcessFeature,$f))
$(foreach b,$(PKG_BINS), $(call ProcessBin,$b))

BUILD_PKGS   := $(sort $(BUILD_PKGS))
RUNTIME_BINS := $(sort $(RUNTIME_BINS))

MODSRC := $(BUILD)
MODDST := $(SQUASHFS_DIR)/lib/modules/$(KERNEL_VERSION)

# --------------------------------------------------------------------

.PHONY: distro extras kernel kernel-headers kmodules busybox run clean \
        ncurses direwolf direwolf-patch menuconfig \
        clean-distro dbg-vars print-vars

distro: $(IMG)

clean-distro:
	rm -rf $(SQUASHFS_DIR)

#---------------------------------------------------------------------

.PHONY: fs-init rootfs initramfs

FS_INIT_SRC := $(ROOT)/fs_init
FS_INIT_PREFIX := $(BUILD)/initramfs
FS_INIT_CC := $(MUSL_CC)
FS_INIT_CFLAGS := -Os -static -I$(LINUX_HEADERS_DIR)/include

fs-init: musl
	@mkdir -p $(FS_INIT_PREFIX)
	$(FS_INIT_CC) $(FS_INIT_CFLAGS) $(FS_INIT_SRC)/fs_init.c -o $(FS_INIT_PREFIX)/init

# gen_init_cpio (built with the kernel) can create device nodes without root,
# so the kernel finds /dev/console and the init's output is visible.
initramfs: fs-init kernel
	printf '%s\n' \
	  'dir /dev 0755 0 0' \
	  'nod /dev/console 0600 0 0 c 5 1' \
	  'dir /proc 0555 0 0' \
	  'file /init $(FS_INIT_PREFIX)/init 0755 0 0' > $(INITRAMFS_LIST)
	$(GEN_INIT_CPIO) $(INITRAMFS_LIST) > $(INITRAMFS)

rootfs: busybox kmodules extras
	mkdir -p $(SQUASHFS_DIR)
	mkdir -p $(SQUASHFS_DIR)/dev
	mkdir -p $(SQUASHFS_DIR)/sys
	mkdir -p $(SQUASHFS_DIR)/proc
	rsync -r $(ROOT)/rootfs/base/ $(SQUASHFS_DIR)/
ifeq ($(CONFIG_NET),y)
	rsync -a $(ROOT)/rootfs/network/ $(SQUASHFS_DIR)/
endif
	cd $(SQUASHFS_DIR)/bin && \
	for c in $$(./busybox --list); do ln -sf busybox $$c; done

	@mkdir -p $(SQUASHFS_DIR)/usr/bin
	@for f in $(RUNTIME_BINS); do \
		cp $$f $(SQUASHFS_DIR)/usr/bin/; \
	done;
	find $(SQUASHFS_DIR) -type f -perm /a+x -print0 | \
	xargs -0 file -i | awk -F: '/application\/x-executable/{print $$1}' | \
	xargs -r strip --strip-all

kmodules: kernel
	@mkdir -p $(MODDST)
	@for list in $(DISTRO_MODLISTS); do \
	  while read -r mod; do \
	    [ -z "$$mod" ] && continue; \
	    src="$(MODSRC)/$$mod"; dst="$(MODDST)/$$mod"; \
	    if [ -f "$$src" ]; then mkdir -p "$$(dirname "$$dst")"; cp "$$src" "$$dst"; fi; \
	  done < "$$list"; \
	done
	depmod -b $(SQUASHFS_DIR) $(KERNEL_VERSION)

# Builds the disk image without root (no losetup/sudo):
# partition table with sfdisk, filesystems built as files and dd'd in place.
# WARNING: rebuilding the image wipes the writable (rw) partition.
$(IMG): rootfs initramfs
	rm -f $(IMG) $(SQUASHFS_IMG) $(RW_IMG)
	mksquashfs $(SQUASHFS_DIR) $(SQUASHFS_IMG) -noappend -all-root -comp xz -b 256k -quiet
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

#---------------------------------------------------------------------

extras: $(BUILD_PKGS)

dbg-vars:
	@echo "DISTRO_MODLISTS  = $(DISTRO_MODLISTS)"
	@echo "BUILD_PKGS  = $(BUILD_PKGS)"
	@echo "RUNTIME_BINS = $(RUNTIME_BINS)"

print-vars:
	@echo "CFLAGS = $(CFLAGS)"
	@echo "LDFLAGS = $(LDFLAGS)"
	@echo "CPPFLAGS = $(CPPFLAGS)"
	@echo "CC = $(CC)"
# --------------------------------------------------------------------

KCONF_BIN    := $(KERNEL_SRC)/scripts/kconfig/mconf
KCONFIG_FILE := Kconfig

menuconfig:
	kconfig-mconf $(KCONFIG_FILE)

kernel: $(KERNEL_BUILD)/arch/x86/boot/bzImage

$(KERNEL_PREPARED):
	@mkdir -p $(SOURCES)
	curl -L $(KERNEL_URL) -o $(SOURCES)/$(KERNEL_TARBALL)
	tar -xf $(SOURCES)/$(KERNEL_TARBALL) -C $(SOURCES)
	@touch $@

$(KERNEL_CONFIGURED): $(KERNEL_PREPARED) configs/kernel.config
	@mkdir -p $(KERNEL_BUILD)
	$(MAKE) -C $(KERNEL_SRC) mrproper
	cp configs/kernel.config $(KERNEL_BUILD)/.config
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) olddefconfig
	@touch $@

$(KERNEL_BUILD)/arch/x86/boot/bzImage: $(KERNEL_CONFIGURED)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) bzImage modules

# Separate O= directory: headers_install must not run in $(KERNEL_BUILD)
# in parallel with the kernel build (make -j).
$(LINUX_HEADERS_INSTALLED): $(KERNEL_CONFIGURED)
	@mkdir -p $(LINUX_HEADERS_DIR)
	$(MAKE) -C $(KERNEL_SRC) O=$(BUILD)/kernel-headers ARCH=x86 \
	        INSTALL_HDR_PATH=$(LINUX_HEADERS_DIR) headers_install
	@touch $@

kernel-headers: $(LINUX_HEADERS_INSTALLED)

# --------------------------------------------------------------------

busybox: $(BUILD)/rootfs/bin/busybox

$(BUSYBOX_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(BUSYBOX_URL) -o $(SOURCES)/$(BUSYBOX_TARBALL)
	tar -xf $(SOURCES)/$(BUSYBOX_TARBALL) -C $(SOURCES)
	cd $(BUSYBOX_SRC)/scripts/kconfig/lxdialog && patch -p0 < $(abspath patches/busybox-lxdiagcheck.patch) || true
	@touch $@

$(BUSYBOX_BUILD)/busybox: $(ROOT)/configs/busybox.config $(BUSYBOX_SRC)/.prepared
	@mkdir -p $(BUSYBOX_BUILD)
	cp $(ROOT)/configs/busybox.config $(BUSYBOX_BUILD)/.config
	CFLAGS="-Os -flto" LDFLAGS="-static -flto" \
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) oldconfig
	CFLAGS="-Os -flto" LDFLAGS="-static -flto" \
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD)

$(BUILD)/rootfs/bin/busybox: $(BUSYBOX_BUILD)/busybox
	@mkdir -p $(BUILD)/rootfs/bin
	cp $< $@
	chmod +x $@

#---------------------------------------------------------------------

QEMU_MEM ?= 30
QEMU_EXTRA ?=
QEMU_NET :=
ifeq ($(CONFIG_NET),y)
QEMU_NET := -netdev user,id=net0 -device virtio-net-pci,netdev=net0
endif

# Does not rebuild an existing disk.img, so data on the rw partition survives.
# -no-reboot: there is no ACPI, so 'reboot' is the way to exit QEMU.
run:
	@[ -f $(IMG) ] || $(MAKE) distro
	qemu-system-x86_64 -m $(QEMU_MEM) -no-reboot \
	    -kernel $(KERNEL_BUILD)/arch/x86/boot/bzImage \
	    -initrd $(INITRAMFS) \
	    -drive file=$(IMG),format=raw,if=virtio \
	    -append "notsc squashfs_dev=/dev/vda1 rw_dev=/dev/vda2" \
	    $(QEMU_NET) $(QEMU_EXTRA)

clean: alsa-lib-clean alsa-utils-clean musl-clean ncurses-clean direwolf-clean libudev-zero-clean ax25-apps-clean ax25-tools-clean lib-ax25-clean
	rm -rf $(LINUX_HEADERS_DIR) $(LINUX_HEADERS_INSTALLED)
	rm -rf $(KERNEL_SRC) $(SOURCES)/$(KERNEL_TARBALL) $(KERNEL_BUILD) $(KERNEL_PREPARED) $(KERNEL_CONFIGURED)
	rm -rf $(BUSYBOX_SRC) $(SOURCES)/$(BUSYBOX_TARBALL) $(BUSYBOX_BUILD)
	rm -rf $(BUILD)
