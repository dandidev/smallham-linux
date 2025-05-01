BUILD := $(shell readlink -f build/current)
KOBJ  := $(BUILD)/kernel
BBOBJ := $(BUILD)/busybox
INIT  := $(BUILD)/initroot
CPIO  := $(BUILD)/init.cpio
ISO   := $(BUILD)/iso
ISOIMG := $(BUILD)/my-linux.iso

.PHONY: all run clean busybox distclean iso

all: kernel busybox $(CPIO)


kernel: $(KOBJ)/arch/x86/boot/bzImage
$(KOBJ)/.config: modules/mini/kernel.config
	cp $< $@
$(KOBJ)/arch/x86/boot/bzImage: $(KOBJ)/.config
	$(MAKE) -C sources/linux mrproper
	$(MAKE) -C sources/linux O=$(KOBJ) bzImage modules

busybox: $(BBOBJ)/busybox
$(BBOBJ)/.config: modules/mini/busybox.config
	cp $< $@
$(BBOBJ)/busybox: $(BBOBJ)/.config $(KOBJ)/arch/x86/boot/bzImage
	$(MAKE) -C sources/busybox mrproper
	$(MAKE) -C sources/busybox O=$(BBOBJ)

# BusyBox setup links ----------
$(INIT)/bin/busybox: $(BBOBJ)/busybox
	cp $(BBOBJ)/busybox $(INIT)/bin/busybox
	chmod +x $(INIT)/bin/busybox
	cd $(INIT)/bin && \
	ln -sf bin/init ../init && \
	for cmd in $$(./busybox --list); do \
		ln -sf busybox $$cmd; \
	done

# Initramfs --------------------
$(CPIO): $(INIT)/bin/busybox $(shell find $(INIT) -type f)
	(cd $(INIT) && find . | cpio -o -H newc --quiet) > $@

run: all
	qemu-system-x86_64 -m 40 \
	    -kernel $(KOBJ)/arch/x86/boot/bzImage \
	    -initrd $(CPIO) -append "notsc"

iso:
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