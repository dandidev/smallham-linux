include .config

# --------------------------------------------------------------------

ROOT := $(CURDIR)
SOURCES := $(ROOT)/sources
BUILD := $(ROOT)/build
PREFIX := $(ROOT)/toolchain
INITROOT := $(BUILD)/initroot

# --------------------------------------------------------------------

DISK_SIZE_MB := 8
SQUASHFS_SIZE_MB := 6

IMG := $(ROOT)/disk.img
SQUASHFS_IMG := $(ROOT)/squashfs.img
SQUASHFS_DIR := $(BUILD)/rootfs

ISO := $(BUILD)/iso
ISOIMG := $(BUILD)/my-linux.iso

# --------------------------------------------------------------------

KERNEL_VERSION := 6.6.30
KERNEL_TARBALL := linux-$(KERNEL_VERSION).tar.xz
KERNEL_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL_TARBALL)
KERNEL_SRC := $(SOURCES)/linux-$(KERNEL_VERSION)
KERNEL_BUILD := $(BUILD)/kernel
LINUX_HEADERS_DIR := $(PREFIX)/linux-headers

BUSYBOX_VERSION := 1.37.0
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_SRC := $(SOURCES)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD := $(BUILD)/busybox

MUSL_VERSION := 1.2.4
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_SRC := $(SOURCES)/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(PREFIX)/musl

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

.PHONY: extras kernel busybox run clean distclean iso \
        ncurses direwolf direwolf-patch \
        clean-distro dbg-vars

distro: $(INITROOT)/init.cpio

clean-distro:
	rm -rf $(SQUASHFS_DIR)

#---------------------------------------------------------------------

.PHONY: fs-init rootfs initramfs

FS_INIT_SRC := $(ROOT)/fs_init
FS_INIT_PREFIX := $(BUILD)/initramfs
FS_INIT_CC := $(MUSL_PATH)/bin/musl-gcc
FS_INIT_CFLAGS := -Os -static -I$(LINUX_HEADERS_DIR)/include

$(FS_INIT_PREFIX)/init_fs: musl

fs-init:
	@mkdir -p $(FS_INIT_PREFIX)
	$(FS_INIT_CC) $(FS_INIT_CFLAGS) $(FS_INIT_SRC)/fs_init.c -o $(FS_INIT_PREFIX)/init

initramfs: fs-init
	cd $(BUILD)/initramfs && \
	find . | cpio -o -H newc --quiet > $(BUILD)/initramfs.cpio

rootfs: busybox kmodules extras
	mkdir -p $(SQUASHFS_DIR)
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

kmodules:
	@mkdir -p $(MODDST)
	@for list in $(DISTRO_MODLISTS); do \
	  while read -r mod; do \
	    [ -z "$$mod" ] && continue; \
	    src="$(MODSRC)/$$mod"; dst="$(MODDST)/$$mod"; \
	    if [ -f "$$src" ]; then mkdir -p "$$(dirname "$$dst")"; cp "$$src" "$$dst"; fi; \
	  done < "$$list"; \
	done
	depmod -b $(SQUASHFS_DIR) $(KERNEL_VERSION)

disks: $(IMG)

$(IMG): rootfs initramfs
	dd if=/dev/zero of=$(IMG) bs=1M count=$(DISK_SIZE_MB)

	echo "label: dos" > partitions.txt
	echo "label-id: 0x12345678" >> partitions.txt
	echo "unit: sectors" >> partitions.txt
	echo "$(IMG)1 : start=2048, size=$(shell echo $$(($(SQUASHFS_SIZE_MB)*2048))), type=83" >> partitions.txt
	echo "$(IMG)2 : start=$(shell echo $$(($(SQUASHFS_SIZE_MB)*2048 + 2048))), type=83" >> partitions.txt
	sfdisk $(IMG) < partitions.txt
#	rm partitions.txt

	LOOP=$$(sudo losetup --show -fP $(IMG)); \
	echo "Loop device: $$LOOP"; \
	mksquashfs $(SQUASHFS_DIR) $(SQUASHFS_IMG) -noappend -comp xz -b 256k; \
	sudo dd if=$(SQUASHFS_IMG) of=$${LOOP}p1 bs=1M conv=fsync status=none; \
	sudo mkfs.ext2 -q $${LOOP}p2; \
	sudo losetup -d $$LOOP; \
	rm $(SQUASHFS_IMG)

#---------------------------------------------------------------------

extras: $(BUILD_PKGS)

dbg-vars:
	@echo "DISTRO_MODLISTS  = $(DISTRO_MODLISTS)"
	@echo "BUILD_PKGS  = $(BUILD_PKGS)"
	@echo "RUNTIME_BINS = $(RUNTIME_BINS)"

# --------------------------------------------------------------------

KCONF_BIN    := $(KERNEL_SRC)/scripts/kconfig/mconf
KCONFIG_FILE := Kconfig

menuconfig:
	kconfig-mconf $(KCONFIG_FILE)

kernel: $(KERNEL_BUILD)/arch/x86/boot/bzImage

$(KERNEL_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(KERNEL_URL) -o $(SOURCES)/$(KERNEL_TARBALL)
	tar -xf $(SOURCES)/$(KERNEL_TARBALL) -C $(SOURCES)
	@touch $@

$(KERNEL_BUILD)/.configured: $(KERNEL_SRC)/.prepared configs/kernel.config
	@mkdir -p $(KERNEL_BUILD)
	$(MAKE) -C $(KERNEL_SRC) mrproper
	cp configs/kernel.config $(KERNEL_BUILD)/.config
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) olddefconfig
	@touch $@

$(KERNEL_BUILD)/arch/x86/boot/bzImage: $(KERNEL_BUILD)/.configured
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) bzImage modules

$(LINUX_HEADERS_DIR)/.installed: $(KERNEL_BUILD)/.configured
	@mkdir -p $(LINUX_HEADERS_DIR)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) \
	        INSTALL_HDR_PATH=$(LINUX_HEADERS_DIR) headers_install
	@touch $@

kernel-headers: $(LINUX_HEADERS_DIR)/.installed

# --------------------------------------------------------------------

busybox: $(BUILD)/rootfs/bin/busybox

$(BUSYBOX_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(BUSYBOX_URL) -o $(SOURCES)/$(BUSYBOX_TARBALL)
	tar -xf $(SOURCES)/$(BUSYBOX_TARBALL) -C $(SOURCES)
	@touch $@

$(BUSYBOX_BUILD)/busybox: configs/busybox.config $(BUSYBOX_SRC)/.prepared
	@mkdir -p $(BUSYBOX_BUILD)
	cp configs/busybox.config $(BUSYBOX_BUILD)/.config
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) oldconfig
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD)

$(BUILD)/rootfs/bin/busybox: $(BUSYBOX_BUILD)/busybox
	@mkdir -p $(BUILD)/rootfs/bin
	cp $< $@
	chmod +x $@

#---------------------------------------------------------------------

$(MUSL_SRC)/.prepared:
	curl -L $(MUSL_URL) -o $(SOURCES)/$(MUSL_TARBALL);
	tar -xzf $(SOURCES)/$(MUSL_TARBALL) -C $(SOURCES);
	@touch $@

musl: $(MUSL_SRC)/.prepared | kernel-headers
	cd $(MUSL_SRC) && make distclean || true
	cd $(MUSL_SRC) && CFLAGS="-Os -I$(LINUX_HEADERS_DIR)/include" ./configure --prefix=$(MUSL_PREFIX) --syslibdir=$(MUSL_PREFIX)/lib
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install

export MUSL_PREFIX := $(MUSL_PREFIX)
export MUSL_CC := $(MUSL_PREFIX)/bin/musl-gcc

#---------------------------------------------------------------------

run: distro
	qemu-system-x86_64 -m 40 \
	    -kernel $(KERNEL_BUILD)/arch/x86/boot/bzImage \
	    -initrd $(CPIO) -append "notsc"

iso: distro
	cp $(KERNEL_BUILD)/arch/x86/boot/bzImage $(ISO)
	cp $(CPIO) $(ISO)/init.cpio
	cp /usr/lib/syslinux/bios/isolinux.bin $(ISO)/isolinux/
	cp /usr/lib/syslinux/bios/ldlinux.c32 $(ISO)/isolinux/
	genisoimage -o $(ISOIMG) -b isolinux/isolinux.bin \
	  -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
	  -boot-info-table -iso-level 3 -quiet $(ISO)

clean:
	rm -rf $(BUILD)/*
	rm -rf $(PREFIX)/*
