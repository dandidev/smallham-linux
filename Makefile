include .config

# --------------------------------------------------------------------

ROOT := $(CURDIR)
SOURCES := $(ROOT)/sources
BUILD := $(ROOT)/build
PREFIX := $(ROOT)/toolchain
INITROOT := $(BUILD)/initroot

CPIO := $(BUILD)/init.cpio
ISO := $(BUILD)/iso
ISOIMG := $(BUILD)/my-linux.iso

# --------------------------------------------------------------------

include $(wildcard packages/*.mk)

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

LIB_AX25_REPO := https://github.com/dandidev/libax25.git
LIB_AX25_SRC := $(SOURCES)/ax25-lib
LIB_AX25_PREFIX := $(PREFIX)/lib-ax25

AX25_TOOLS_REPO := https://github.com/dandidev/ax25-tools.git
AX25_TOOLS_SRC := $(SOURCES)/ax25-tools
AX25_TOOLS_PREFIX := $(BUILD)/ax25-tools
AX25_TOOLS_INITROOT := $(INITROOT)/usr/bin

AX25_APPS_REPO := https://github.com/dandidev/ax25-apps.git
AX25_APPS_SRC := $(SOURCES)/ax25-apps
AX25_APPS_PREFIX := $(BUILD)/ax25-apps
AX25_APPS_INITROOT := $(INITROOT)/usr/bin

NCURSES_VERSION := 6.4
NCURSES_TARBALL := ncurses-$(NCURSES_VERSION).tar.gz
NCURSES_URL := https://ftp.gnu.org/pub/gnu/ncurses/$(NCURSES_TARBALL)
NCURSES_SRC := $(SOURCES)/ncurses-$(NCURSES_VERSION)
NCURSES_PREFIX := $(PREFIX)/ncurses

DIREWOLF_REPO := https://github.com/wb2osz/direwolf.git
DIREWOLF_SRC := $(SOURCES)/direwolf
DIREWOLF_BUILD := $(BUILD)/direwolf
DIREWOLF_PREFIX := $(BUILD)/direwolf
DIREWOLF_CMAKE_PATCH := patches/direwolf-cmakelists.patch
DIREWOLF_SRC_CMAKE_PATCH := patches/direwolf-src-cmakelists.patch

ALSA_VERSION := 1.2.14
ALSA_TARBALL := alsa-lib-$(ALSA_VERSION).tar.bz2
ALSA_URL := https://www.alsa-project.org/files/pub/lib/$(ALSA_TARBALL)
ALSA_SRC := $(SOURCES)/alsa-lib-$(ALSA_VERSION)
ALSA_PREFIX := $(PREFIX)/alsa

MUSL_VERSION := 1.2.4
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_SRC := $(SOURCES)/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(PREFIX)/musl

LIBUDEVZERO_VERSION := 1.0.3
LIBUDEVZERO_TARBALL := libudev-zero-$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_URL := https://github.com/illiliti/libudev-zero/archive/refs/tags/$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_SRC := $(SOURCES)/libudev-zero-$(LIBUDEVZERO_VERSION)
LIBUDEVZERO_PREFIX := $(PREFIX)/libudev-zero

# --------------------------------------------------------------------
PKG_FEATURES += LIB_AX25|ax25-lib
PKG_FEATURES += AX25_TOOLS|ax25-tools
PKG_FEATURES += AX25_APPS|ax25-apps
PKG_FEATURES += DIREWOLF|direwolf

PKG_BINS += AX25_TOOLS_NETROMD|$(AX25_TOOLS_PREFIX)/usr/sbin/netromd
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissattach
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissparms
PKG_BINS += AX25_APPS_CALL|$(AX25_APPS_PREFIX)/usr/bin/call
PKG_BINS += AX25_APPS_LISTEN|$(AX25_APPS_PREFIX)/usr/bin/listen
PKG_BINS += AX25_APPS_IPD|$(AX25_APPS_PREFIX)/usr/sbin/ax25ipd
PKG_BINS += DIREWOLF|$(DIREWOLF_PREFIX)/usr/bin/direwolf

# --------------------------------------------------------------------

DISTRO_MODLISTS :=
BUILD_PKGS  :=
RUNTIME_BINS :=

bar := |

_split = $(word $(1),$(subst $(bar), ,$(2)))

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
MODMAP += FS|modules/fs.modlist
MODMAP += OVERLAY_FS|modules/overlay-fs.modlist
MODMAP += NET|modules/network.modlist
MODMAP += NET|modules/lib.modlist
MODMAP += SOUND|modules/sound.modlist
MODMAP += SOUND|modules/lib.modlist

# --------------------------------------------------------------------

$(foreach m,$(MODMAP),		$(call ProcessKernelModules,$(m)))
$(foreach f,$(PKG_FEATURES),$(call ProcessFeature,$f))
$(foreach b,$(PKG_BINS)      ,$(call ProcessBin,$b))

BUILD_PKGS   := $(sort $(BUILD_PKGS))
RUNTIME_BINS := $(sort $(RUNTIME_BINS))

MODSRC := $(BUILD)
MODDST := $(INITROOT)/lib/modules/$(KERNEL_VERSION)

# --------------------------------------------------------------------

.PHONY: extras kernel busybox run clean distclean iso \
        ax25-lib ncurses direwolf direwolf-patch \
        clean-distro dbg-vars

distro: $(INITROOT)/init.cpio

clean-distro:
	rm -rf $(INITROOT)

create-initfs-symlinks: busybox
	cd $(INITROOT)/bin && ln -sf bin/init ../init && \
	for c in $$(./busybox --list); do ln -sf busybox $$c; done

create-initfs-modules: kernel
	rsync -r modules/base/initroot/ $(INITROOT)/
ifeq ($(CONFIG_NET),y)
	rsync -r modules/network/initroot/ $(INITROOT)/
endif
	@mkdir -p $(MODDST)
	@for list in $(DISTRO_MODLISTS); do \
	  while read -r mod; do \
	    [ -z "$$mod" ] && continue; \
	    src="$(MODSRC)/$$mod"; dst="$(MODDST)/$$mod"; \
	    if [ -f "$$src" ]; then mkdir -p "$$(dirname "$$dst")"; cp "$$src" "$$dst"; fi; \
	  done < "$$list"; \
	done
	depmod -b $(INITROOT) $(KERNEL_VERSION)

$(INITROOT)/init.cpio: create-initfs-modules create-initfs-symlinks extras
	@mkdir -p $(INITROOT)/usr/bin
	@for f in $(RUNTIME_BINS); do \
		cp $$f $(INITROOT)/usr/bin/; \
	done;
	find $(INITROOT) -type f -perm /a+x -print0 | \
	xargs -0 file -i | awk -F: '/application\/x-executable/{print $$1}' | \
	xargs -r strip --strip-all
	cd $(INITROOT) && find . | cpio -o -H newc --quiet > $(BUILD)/init.cpio

#---------------------------------------------------------------------

extras: $(BUILD_PKGS)

dbg-vars:
	@echo "DISTRO_MODLISTS  = $(DISTRO_MODLISTS)"
	@echo "BUILD_PKGS  = $(BUILD_PKGS)"
	@echo "DIREWOLF_BINS = $(RUNTIME_BINS)"

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

$(KERNEL_BUILD)/.configured: $(KERNEL_SRC)/.prepared modules/base/kernel.config
	@mkdir -p $(KERNEL_BUILD)
	$(MAKE) -C $(KERNEL_SRC) mrproper
	cp modules/base/kernel.config $(KERNEL_BUILD)/.config
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

busybox: $(INITROOT)/bin/busybox

$(BUSYBOX_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(BUSYBOX_URL) -o $(SOURCES)/$(BUSYBOX_TARBALL)
	tar -xf $(SOURCES)/$(BUSYBOX_TARBALL) -C $(SOURCES)
	@touch $@

$(BUSYBOX_BUILD)/busybox: modules/base/busybox.config $(BUSYBOX_SRC)/.prepared
	@mkdir -p $(BUSYBOX_BUILD)
	cp modules/base/busybox.config $(BUSYBOX_BUILD)/.config
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) oldconfig
	$(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD)

$(INITROOT)/bin/busybox: $(BUSYBOX_BUILD)/busybox
	@mkdir -p $(INITROOT)/bin
	cp $< $@
	chmod +x $@

# --------------------------------------------------------------------

$(LIB_AX25_SRC)/.prepared:
	git clone --depth 1 $(LIB_AX25_REPO) $(LIB_AX25_SRC) || true
	@touch $@

$(AX25_TOOLS_SRC)/.prepared:
	git clone --depth 1 $(AX25_TOOLS_REPO) $(AX25_TOOLS_SRC) || true
	@touch $@

$(AX25_APPS_SRC)/.prepared:
	git clone --depth 1 $(AX25_APPS_REPO) $(AX25_APPS_SRC) || true
	@touch $@

ax25-lib: $(LIB_AX25_SRC)/.prepared | kernel-headers
	@mkdir -p $(LIB_AX25_PREFIX)
	cd $(LIB_AX25_SRC) && autoreconf -fi
	cd $(LIB_AX25_SRC) && \
		CFLAGS="-Os -I$(LINUX_HEADERS_DIR)/include" \
		LDFLAGS="--static" \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(LIB_AX25_SRC)
	$(MAKE) -C $(LIB_AX25_SRC) DESTDIR=$(LIB_AX25_PREFIX) install

ax25-tools: ax25-lib $(AX25_TOOLS_SRC)/.prepared
	@mkdir -p $(AX25_TOOLS_PREFIX)
	cd $(AX25_TOOLS_SRC) && libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	cd $(AX25_TOOLS_SRC) && CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib -static" CFLAGS="-Os" ./configure --prefix=/usr --without-x
	$(MAKE) -C $(AX25_TOOLS_SRC)
	$(MAKE) -C $(AX25_TOOLS_SRC) DESTDIR=$(AX25_TOOLS_PREFIX) install
	@mkdir -p $(AX25_TOOLS_INITROOT)

ax25-apps: ax25-tools ncurses $(AX25_APPS_SRC)/.prepared
	@mkdir -p $(AX25_APPS_PREFIX)
	cd $(AX25_APPS_SRC) && autoreconf --install --force
	cd $(AX25_APPS_SRC) && CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" \
		LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib -L$(NCURSES_PREFIX)/usr/lib -static" \
		CFLAGS="-Os" ./configure --prefix=/usr --enable-static
	$(MAKE) -C $(AX25_APPS_SRC)
	$(MAKE) -C $(AX25_APPS_SRC) DESTDIR=$(AX25_APPS_PREFIX) install
	@mkdir -p $(AX25_APPS_INITROOT)

#---------------------------------------------------------------------

$(NCURSES_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(NCURSES_URL) | tar xz -C $(SOURCES)
	@touch $@

$(NCURSES_PREFIX)/.installed: $(NCURSES_SRC)/.prepared
#	cd $(NCURSES_SRC) && make distclean || true
	cd $(NCURSES_SRC) && ./configure --prefix=/usr --enable-widec --enable-static --disable-shared --with-normal --without-debug
	cd $(NCURSES_SRC) && make
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(NCURSES_PREFIX)
	@touch $@

ncurses: $(NCURSES_PREFIX)/.installed

#---------------------------------------------------------------------

$(DIREWOLF_SRC)/.prepared:
	git clone --depth 1 $(DIREWOLF_REPO) $(DIREWOLF_SRC) || true
	@touch $@

direwolf-patch: $(DIREWOLF_SRC)/.prepared
	cd $(DIREWOLF_SRC) && git clean -fdx && git reset --hard
	cd $(DIREWOLF_SRC) && mkdir -p build
	cd $(DIREWOLF_SRC) && patch -p0 < $(abspath $(DIREWOLF_CMAKE_PATCH)) || true
	cd $(DIREWOLF_SRC)/src && patch -p0 < $(abspath $(DIREWOLF_SRC_CMAKE_PATCH)) || true

direwolf: direwolf-patch libudev-zero alsa-lib
	cd $(DIREWOLF_SRC) && cmake \
	  -DCMAKE_SYSTEM_NAME=smallham-linux \
	  -DEXTERNAL_ALSA_LIB=$(ALSA_PREFIX)/usr/lib/libasound.a \
	  -DEXTERNAL_UDEV_LIB=$(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a \
	  -DCMAKE_INSTALL_PREFIX=/usr \
	  -DINSTALL_BIN_DIR=/usr/bin \
	  -DCMAKE_BUILD_TYPE=MinSizeRel \
	  -DCMAKE_C_COMPILER=$(MUSL_CC) \
	  -DCMAKE_FIND_ROOT_PATH=$(PREFIX) \
	  -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -isystem $(LINUX_HEADERS_DIR)/include -I$(ALSA_PREFIX)/usr/include -I$(LIBUDEVZERO_PREFIX)/usr/include" \
	  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive $(ALSA_PREFIX)/usr/lib/libasound.a $(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a -Wl,--no-whole-archive -static"
	cd $(DIREWOLF_SRC) && make
	@mkdir -p $(DIREWOLF_PREFIX)
	cd $(DIREWOLF_SRC) && make DESTDIR=$(DIREWOLF_PREFIX) install
	strip $(DIREWOLF_PREFIX)/usr/bin/direwolf
	@mkdir -p $(INITROOT)/usr/bin
	cp $(DIREWOLF_PREFIX)/usr/bin/direwolf $(INITROOT)/usr/bin

#---------------------------------------------------------------------

$(ALSA_SRC)/.prepared:
	curl -L $(ALSA_URL) -o $(SOURCES)/$(ALSA_TARBALL);
	tar xjf $(SOURCES)/$(ALSA_TARBALL) -C $(SOURCES);
	@touch $@

alsa-lib: $(ALSA_SRC)/.prepared musl
	cd $(ALSA_SRC) && CC=$(MUSL_CC) ./configure \
		--prefix=/usr \
		--enable-static \
		--disable-shared \
		--disable-python \
		--disable-aload \
		--disable-ucm \
		--disable-mixer \
		--disable-old-symbols \
		CFLAGS="-Os -ffunction-sections -fdata-sections -I$(LINUX_HEADERS_DIR)/include" \
		LDFLAGS="-Wl,--gc-sections"
	cd $(ALSA_SRC) && make
	cd $(ALSA_SRC) && make DESTDIR=$(ALSA_PREFIX) install

#---------------------------------------------------------------------

$(MUSL_SRC)/.prepared:
	curl -L $(MUSL_URL) -o $(SOURCES)/$(MUSL_TARBALL);
	tar -xzf $(SOURCES)/$(MUSL_TARBALL) -C $(SOURCES);
	@touch $@

musl: $(MUSL_SRC)/.prepared | kernel-headers
	cd $(MUSL_SRC) && make distclean || true
	cd $(MUSL_SRC) && CFLAGS="-Os -I$(LINUX_HEADERS_DIR)/include" ./configure --prefix=$(MUSL_PREFIX)
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install

export MUSL_PREFIX := $(MUSL_PREFIX)
export MUSL_CC := $(MUSL_PREFIX)/bin/musl-gcc

#---------------------------------------------------------------------

$(LIBUDEVZERO_SRC)/.prepared:
	curl -L $(LIBUDEVZERO_URL) -o $(SOURCES)/$(LIBUDEVZERO_TARBALL);
	tar xzf $(SOURCES)/$(LIBUDEVZERO_TARBALL) -C $(SOURCES);
	@touch $@

libudev-zero: $(LIBUDEVZERO_SRC)/.prepared
	cd $(LIBUDEVZERO_SRC) && LDFLAGS="-s" make
	cd $(LIBUDEVZERO_SRC) && make PREFIX=$(LIBUDEVZERO_PREFIX)/usr install

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
