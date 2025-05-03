include .config

KCONF_BIN := sources/linux/scripts/kconfig/mconf
KCONF_SRC := sources/linux/scripts/kconfig
KCONFIG_FILE := Kconfig

DISTRO_MODLISTS := 

ifeq ($(CONFIG_HAM),y)
  DISTRO_MODLISTS += modules/ham/ham.modlist
endif
ifeq ($(CONFIG_USB),y)
	DISTRO_MODLISTS += modules/usb/usb.modlist
endif
ifeq ($(CONFIG_USB_STORAGE),y)
	DISTRO_MODLISTS += modules/usb-storage/usb-storage.modlist
endif
ifeq ($(CONFIG_FS),y)
  DISTRO_MODLISTS += modules/fs.modlist
endif
ifeq ($(CONFIG_OVERLAY_FS),y)
  DISTRO_MODLISTS += modules/overlay-fs.modlist
endif
ifeq ($(CONFIG_NET),y)
  DISTRO_MODLISTS += modules/network.modlist
endif
ifeq ($(CONFIG_SOUND),y)
  DISTRO_MODLISTS += modules/sound.modlist
endif

BUILD := $(shell readlink -f build/current)
KOBJ  := $(BUILD)/kernel
BBOBJ := $(BUILD)/busybox
INIT  := $(BUILD)/initroot
CPIO  := $(BUILD)/init.cpio
ISO   := $(BUILD)/iso
ISOIMG := $(BUILD)/my-linux.iso

.PHONY: all run clean busybox distclean iso

all: kernel busybox

menuconfig:
	kconfig-mconf Kconfig


kernel: $(KOBJ)/arch/x86/boot/bzImage
$(KOBJ)/.config: modules/base/kernel.config
	cp $< $@
$(KOBJ)/arch/x86/boot/bzImage: $(KOBJ)/.config
	$(MAKE) -C sources/linux mrproper
	$(MAKE) -C sources/linux O=$(KOBJ) KERNELRELEASE=6.15.0-rc3 olddefconfig
	$(MAKE) -C sources/linux O=$(KOBJ) KERNELRELEASE=6.15.0-rc3 bzImage modules

busybox: $(INIT)/bin/busybox
$(BBOBJ)/.config: modules/base/busybox.config
	cp $< $@

$(BBOBJ)/busybox: $(BBOBJ)/.config $(KOBJ)/arch/x86/boot/bzImage
	$(MAKE) -C sources/busybox mrproper
	$(MAKE) -C sources/busybox O=$(BBOBJ)

$(INIT)/bin/busybox: $(BBOBJ)/busybox
	cp $(BBOBJ)/busybox $(INIT)/bin/busybox
	chmod +x $(INIT)/bin/busybox
	cd $(INIT)/bin && \
	ln -sf bin/init ../init && \
	for cmd in $$(./busybox --list); do \
		ln -sf busybox $$cmd; \
	done

distro: $(KOBJ)/arch/x86/boot/bzImage $(BBOBJ)/busybox
	@echo ">>> Preparing initroot"
	@echo "		+ Append base initroot"
	rsync modules/base/initroot/ $(INIT)/
ifeq ($(CONFIG_NET),y)
	@echo "		+ Append network initroot"
	rsync modules/network/initroot/ $(INIT)/
else
	
endif
	@echo ">>> Running distro builder"
	./distro-builder $(DISTRO_MODLISTS)

run: distro
	qemu-system-x86_64 -m 40 \
	    -kernel $(KOBJ)/arch/x86/boot/bzImage \
	    -initrd $(CPIO) -append "notsc"

iso: distro
	cp $(KOBJ)/arch/x86/boot/bzImage $(ISO)
	cp $(CPIO) $(ISO)/init.cpio
	cp /usr/lib/syslinux/bios/isolinux.bin $(ISO)/isolinux/
	cp /usr/lib/syslinux/bios/ldlinux.c32 $(ISO)/isolinux/
	genisoimage -o $(ISOIMG) \
	  -b isolinux/isolinux.bin \
	  -c isolinux/boot.cat \
	  -no-emul-boot -boot-load-size 4 -boot-info-table \
	  -iso-level 3 -quiet \
	  $(ISO)
	@echo "ISO Created: $(ISOIMG)"

clean:
	rm -rf build/*

distclean:
	$(MAKE) -C sources/busybox O=$(BBOBJ) distclean
	$(MAKE) -C sources/linux  O=$(KOBJ)  distclean