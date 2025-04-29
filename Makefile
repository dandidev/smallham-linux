BUILD := $(shell readlink -f build/current)
KOBJ  := $(BUILD)/kernel
BBOBJ := $(BUILD)/busybox
INIT  := $(BUILD)/initroot
CPIO  := $(BUILD)/init.cpio

.PHONY: all run clean busybox distclean

all: $(CPIO)

# Kernel ----------------------
$(KOBJ)/arch/x86/boot/bzImage: $(KOBJ)/.config
	$(MAKE) -C sources/linux mrproper
	$(MAKE) -C sources/linux O=$(KOBJ)

# BusyBox ----------------------
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

busybox: $(INIT)/bin/busybox

# Initramfs --------------------
$(CPIO): $(INIT)/bin/busybox $(shell find $(INIT) -type f)
	(cd $(INIT) && find . | cpio -o -H newc --quiet) > $@

run: all
	qemu-system-x86_64 -m 40 \
	    -kernel $(KOBJ)/arch/x86/boot/bzImage \
	    -initrd $(CPIO) -append "notsc"

clean:
	rm -rf build/*

distclean:
	$(MAKE) -C sources/busybox O=$(BBOBJ) distclean
	$(MAKE) -C sources/linux  O=$(KOBJ)  distclean