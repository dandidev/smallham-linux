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
KERNEL_PREPARED := $(STAMP)/kernel.prepared
KERNEL_CONFIGURED := $(STAMP)/kernel.configured

LINUX_HEADERS_DIR := $(PREFIX)/linux-headers
LINUX_HEADERS_INSTALLED := $(STAMP)/linux-headers.installed

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

.PHONY: extras kernel busybox run clean iso \
        ncurses direwolf direwolf-patch \
        clean-distro dbg-vars

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

initramfs: fs-init
	cd $(BUILD)/initramfs && \
	find . | cpio -o -H newc --quiet > $(BUILD)/initramfs.cpio

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

$(LINUX_HEADERS_INSTALLED): $(KERNEL_CONFIGURED)
	@mkdir -p $(LINUX_HEADERS_DIR)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) \
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

run: distro
	qemu-system-x86_64 -m 40 \
	    -kernel $(KERNEL_BUILD)/arch/x86/boot/bzImage \
	    -initrd $(CPIO) -append "notsc"

DISK_VDMK := disk.vmdk

$(DISK_VDMK):
	qemu-img convert -f raw -O vmdk disk.img disk.vmdk

iso: distro $(DISK_VDMK)
	@mkdir -p $(ISO)/isolinux/
	cp $(KERNEL_BUILD)/arch/x86/boot/bzImage $(ISO)
	cp $(BUILD)/initramfs.cpio $(ISO)/initramfs.cpio
	cp /usr/lib/syslinux/bios/isolinux.bin $(ISO)/isolinux/
	cp /usr/lib/syslinux/bios/ldlinux.c32 $(ISO)/isolinux/
	cp $(ROOT)/iso/isolinux/isolinux.cfg $(ISO)/isolinux/
	genisoimage -o $(ISOIMG) -b isolinux/isolinux.bin \
	  -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
	  -boot-info-table -iso-level 3 -quiet $(ISO)

clean-iso:
	rm -rf $(DISK_VDMK) $(ISO)

clean: alsa-lib-clean alsa-utils-clean musl-clean ncurses-clean direwolf-clean libudev-zero-clean ax25-apps-clean ax25-tools-clean lib-ax25-clean
	rm -rf $(LINUX_HEADERS_DIR) $(LINUX_HEADERS_INSTALLED)
	rm -rf $(KERNEL_SRC) $(SOURCES)/$(KERNEL_TARBALL) $(KERNEL_BUILD) $(KERNEL_PREPARED) $(KERNEL_CONFIGURED)
	rm -rf $(BUSYBOX_SRC) $(SOURCES)/$(BUSYBOX_TARBALL) $(BUSYBOX_BUILD)
	rm -rf $(BUILD)
