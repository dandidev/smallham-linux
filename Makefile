include .config

BUILD := $(shell readlink -f build)
TOOLCHAIN := $(abspath toolchain)
KOBJ  := $(BUILD)/kernel
BBOBJ := $(BUILD)/busybox
INITROOT := $(BUILD)/initroot
CPIO  := $(BUILD)/init.cpio
ISO   := $(BUILD)/iso
ISOIMG := $(BUILD)/my-linux.iso

KCONF_BIN := sources/linux/scripts/kconfig/mconf
KCONF_SRC := sources/linux/scripts/kconfig
KCONFIG_FILE := Kconfig

DISTRO_MODLISTS := modules/lib.modlist

ifeq ($(CONFIG_HAM),y)
  DISTRO_MODLISTS += modules/ham.modlist
endif
ifeq ($(CONFIG_USB),y)
	DISTRO_MODLISTS += modules/usb.modlist
endif
ifeq ($(CONFIG_USB_STORAGE),y)
	DISTRO_MODLISTS += modules/usb-storage.modlist
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

AX25_MODULES :=

ifeq ($(CONFIG_LIB_AX25),y)
    AX25_MODULES += ax25-lib
endif
ifeq ($(CONFIG_AX25_TOOLS),y)
    AX25_MODULES += ax25-tools
endif
ifeq ($(CONFIG_AX25_APPS),y)
    AX25_MODULES += ax25-apps
endif

AX25_TOOLS_BINARIES := 
AX25_APPS_BINARIES := 

ifeq ($(CONFIG_AX25_TOOLS_NETROMD),y)
    AX25_TOOLS_BINARIES += netromd
endif
ifeq ($(CONFIG_AX25_TOOLS_KISS),y)
    AX25_TOOLS_BINARIES += kissattach kissparms
endif

ifeq ($(CONFIG_AX25_APPS_CALL),y)
    AX25_APPS_BINARIES += call
endif
ifeq ($(CONFIG_AX25_APPS_MONITOR),y)
    AX25_APPS_BINARIES += ax25mond
endif

SOURCES := sources

LINUX_VERSION := 6.6.30
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
LINUX_SRC := $(SOURCES)/linux-$(LINUX_VERSION)
LINUX_HEADERS_DIR := $(abspath toolchain/linux-headers)
BZIMAGE := $(LINUX_SRC)/arch/x86/boot/bzImage

BUSYBOX_VERSION := 1.37.0
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BUSYBOX_SRC := sources/busybox-$(BUSYBOX_VERSION)

LIB_AX25_REPO := https://github.com/dandidev/libax25
LIB_AX25_SRC := $(SOURCES)/ax25-lib
LIB_AX25_PREFIX := $(TOOLCHAIN)/lib-ax25

AX25_TOOLS_REPO := https://github.com/dandidev/ax25-tools
AX25_TOOLS_SRC := $(SOURCES)/ax25-tools
AX25_TOOLS_PREFIX := $(INITROOT)/usr/bin

AX25_APPS_REPO := https://github.com/dandidev/ax25-apps
AX25_APPS_SRC := $(SOURCES)/ax25-apps
AX25_APPS_PREFIX := $(INITROOT)/usr/bin

NCURSES_PREFIX := $(TOOLCHAIN)/ncurses
NCURSES_VERSION := 6.4
NCURSES_TARBALL := ncurses-$(NCURSES_VERSION).tar.gz
NCURSES_URL := https://ftp.gnu.org/pub/gnu/ncurses/$(NCURSES_TARBALL)
NCURSES_SRC := $(SOURCES)/ncurses-$(NCURSES_VERSION)
NCURSES_LIB := $(NCURSES_PREFIX)/usr/lib/libncursesw.a

MODSRC := $(BUILD)
MODDST := "$(INITROOT)/lib/modules/$(LINUX_VERSION)"

.PHONY: all run clean busybox distclean iso

all: kernel busybox

menuconfig:
	kconfig-mconf Kconfig


kernel: $(KOBJ)/arch/x86/boot/bzImage

$(LINUX_TARBALL):
	@echo ">>> Downloading Linux kernel $(LINUX_VERSION)"
	@mkdir -p $(SOURCES)
	curl -L $(LINUX_URL) -o $@

$(LINUX_SRC): $(LINUX_TARBALL)
	@echo ">>> Extracting Linux kernel..."
	tar -xf $< -C $(SOURCES)

$(KOBJ)/.config: $(LINUX_SRC) modules/base/kernel.config
	@echo ">>> Preparing Linux kernel configuration"
	mkdir -p $(KOBJ)
	cp modules/base/kernel.config $@

$(KOBJ)/arch/x86/boot/bzImage: $(KOBJ)/.config
	@echo ">>> Building Linux kernel $(LINUX_VERSION)"
	$(MAKE) -C $(LINUX_SRC) mrproper
	$(MAKE) -C $(LINUX_SRC) O=$(KOBJ) olddefconfig
	$(MAKE) -C $(LINUX_SRC) O=$(KOBJ) bzImage modules


busybox: $(INITROOT)/bin/busybox

$(BUSYBOX_TARBALL):
	@echo ">>> Downloading BusyBox $(BUSYBOX_VERSION)"
	@mkdir -p sources
	curl -L $(BUSYBOX_URL) -o $@

$(BUSYBOX_SRC): $(BUSYBOX_TARBALL)
	@echo ">>> Extracting BusyBox..."
	tar -xf $< -C sources

$(BBOBJ)/.config: $(BUSYBOX_SRC) modules/base/busybox.config
	@echo ">>> Preparing BusyBox configuration"
	mkdir -p $(BBOBJ)
	cp modules/base/busybox.config $@

$(BBOBJ)/busybox: $(BBOBJ)/.config
	@echo ">>> Building BusyBox"
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BBOBJ) oldconfig
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BBOBJ)

$(INITROOT)/bin/busybox: $(BBOBJ)/busybox
	@echo ">>> Installing BusyBox to INITROOT"
	mkdir -p $(INITROOT)/bin
	cp $(BBOBJ)/busybox $(INITROOT)/bin/busybox
	chmod +x $(INITROOT)/bin/busybox


distro: kernel busybox $(INITROOT)/init.cpio

clean-distro: rm -rf build/initroot

create-initfs-symlinks: $(INITROOT)/bin/busybox
	@echo ">>> Creating symlinks for BusyBox"
	cd $(INITROOT)/bin && \
	ln -sf bin/init ../init && \
	for cmd in $$(./busybox --list); do \
		ln -sf busybox $$cmd; \
	done

create-initfs-modules: kernel busybox 
	@echo ">>> Preparing initroot"
	@echo "		+ Append base initroot"
	rsync -r modules/base/initroot/ $(INITROOT)/
ifeq ($(CONFIG_NET),y)
	@echo "		+ Append network initroot"
	rsync -r modules/network/initroot/ $(INITROOT)/
endif
	@echo ">>> Building distro"
	@echo ">>> Copying from module lists:"
	mkdir -p $(MODDST)
	@for list in $(DISTRO_MODLISTS); do \
		echo "  -> $$list"; \
		while read -r mod; do \
			[ -z "$$mod" ] && continue; \
			src="$(MODSRC)/$$mod"; \
			dst="$(MODDST)/$$mod"; \
			if [ -f "$$src" ]; then \
				mkdir -p "$$(dirname "$$dst")"; \
				cp "$$src" "$$dst"; \
				echo "     + $$mod"; \
			else \
				echo "     Missing module: $$mod"; \
			fi; \
		done < "$$list"; \
	done
	echo ">>> Running depmod..."
	depmod -b $(INITROOT) $(LINUX_VERSION)

$(INITROOT)/init.cpio: create-initfs-modules create-initfs-symlinks ax25
	echo ">>> Creating initramfs..."
	cd $(INITROOT) && find . | cpio -o -H newc --quiet > $(BUILD)/init.cpio

.PHONY: install-ax25

ax25: $(AX25_MODULES)
	@echo ">>> Building final distro image..."
	@echo ">>> AX25 Modules installed:"
	@for module in $(AX25_MODULES); do \
		echo "  + $$module"; \
	done
	@echo ">>> AX25 Tools binaries:"
	@for bin in $(AX25_TOOLS_BINARIES); do \
		echo "  + $$bin"; \
	done
	@echo ">>> AX25 Apps binaries:"
	@for bin in $(AX25_APPS_BINARIES); do \
		echo "  + $$bin"; \
	done

.PHONY: ax25-lib

ax25-lib:
	@echo ">>> Downloading AX25 Lib"
	@if [ ! -d "$(LIB_AX25_SRC)" ]; then \
		git clone $(LIB_AX25_REPO) $(LIB_AX25_SRC); \
	else \
		echo "libax25 already cloned."; \
	fi
	@echo ">>> Running autoreconf..."
	cd $(SOURCES)/ax25-lib && autoreconf -fi
	@echo ">>> Building AX25 Lib"
	cd $(SOURCES)/ax25-lib && CFLAGS="-Os" LDFLAGS="-s" \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(SOURCES)/ax25-lib
	@echo ">>> Installing AX25 Lib to toolchain"
	$(MAKE) -C $(SOURCES)/ax25-lib DESTDIR=$(LIB_AX25_PREFIX) install


.PHONY: ax25-tools

ax25-tools: ax25-lib
	@echo ">>> Downloading AX25 Tools"
	@if [ ! -d "$(AX25_TOOLS_SRC)" ]; then \
		git clone $(AX25_TOOLS_REPO) $(AX25_TOOLS_SRC); \
	else \
		echo "ax25-tools already cloned."; \
	fi
	@echo ">>> Running autoreconf..."
	cd $(SOURCES)/ax25-tools && \
		libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	@echo ">>> Building AX25 Tools"
	cd $(SOURCES)/ax25-tools && \
		CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" \
		LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib" \
		CFLAGS="-Os" LDFLAGS="-s" \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(SOURCES)/ax25-tools

	@echo ">>> Installing AX25 Tools to initroot"
	@mkdir -p $(AX25_TOOLS_PREFIX)

	@for bin in $(AX25_TOOLS_BINARIES); do \
		echo ">>> Searching for $$bin..."; \
		found=$$(find $(SOURCES)/ax25-tools -type f -name $$bin); \
		if [ -n "$$found" ]; then \
			echo ">>> Found: $$found -> Installing..."; \
			cp $$found $(AX25_TOOLS_PREFIX)/; \
		else \
			echo ">>> Warning: $$bin not found!"; \
			exit 1; \
		fi; \
	done

.PHONY: ax25-apps

ax25-apps: ax25-lib ax25-tools ncurses-install
	@echo ">>> Downloading AX25 Apps"
	@if [ ! -d "$(AX25_APPS_SRC)" ]; then \
		git clone $(AX25_APPS_REPO) $(AX25_APPS_SRC); \
	else \
		echo "ax25-apps already cloned."; \
	fi
	@echo ">>> Running autoreconf..."
	cd $(SOURCES)/ax25-apps && autoreconf --install --force
	@echo ">>> Building AX25 Apps"
	cd $(SOURCES)/ax25-apps && \
		CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" \
		LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib" \
		CFLAGS="-Os" LDFLAGS="-s" \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(SOURCES)/ax25-apps

	@echo ">>> Installing AX25 Apps to initroot"
	@mkdir -p $(AX25_APPS_PREFIX)

	@for bin in $(AX25_APPS_BINARIES); do \
		echo ">>> Searching for $$bin..."; \
		found=$$(find $(SOURCES)/ax25-apps -type f -name $$bin); \
		if [ -n "$$found" ]; then \
			echo ">>> Found: $$found -> Installing..."; \
			cp $$found $(AX25_APPS_PREFIX)/; \
		else \
			echo ">>> Warning: $$bin not found!"; \
			exit 1; \
		fi; \
	done

ncurses-install: $(NCURSES_LIB)

$(NCURSES_LIB):
	@echo ">>> Downloading ncurses $(NCURSES_VERSION)"
	@if [ ! -d "$(NCURSES_SRC)" ]; then \
		mkdir -p $(SOURCE_DIR); \
		curl -L $(NCURSES_URL) | tar xz -C $(SOURCE_DIR); \
	fi

	@echo ">>> Building ncurses"
	cd $(NCURSES_SRC) && make distclean || true
	cd $(NCURSES_SRC) && ./configure \
		--prefix=/usr \
		--enable-widec \
		--enable-static \
		--disable-shared \
		--with-normal \
		--without-debug

	cd $(NCURSES_SRC) && make -j$$(nproc)
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(NCURSES_PREFIX)


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