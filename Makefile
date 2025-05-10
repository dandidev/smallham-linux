include .config
include direwolf_deps.mk

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
NCURSES_LIB := $(NCURSES_PREFIX)/usr/lib/libncursesw.a

DIREWOLF_REPO := https://github.com/wb2osz/direwolf.git
DIREWOLF_SRC := $(SOURCES)/direwolf
DIREWOLF_BUILD := $(BUILD)/direwolf
DIREWOLF_PREFIX := $(BUILD)/direwolf
DIREWOLF_CMAKE_PATCH := patches/direwolf-cmakelists.patch
DIREWOLF_SRC_CMAKE_PATCH := patches/direwolf-src-cmakelists.patch

# --------------------------------------------------------------------

FEATURES += LIB_AX25|ax25-lib|ax25-lib
FEATURES += AX25_TOOLS|ax25-tools|ax25-tools-build
FEATURES += AX25_APPS|ax25-apps|ax25-apps-build

BINMAP += AX25_TOOLS_NETROMD|$(AX25_TOOLS_PREFIX)/usr/sbin/netromd
BINMAP += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissattach
BINMAP += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissparms
BINMAP += AX25_APPS_CALL|$(AX25_APPS_PREFIX)/usr/bin/call
BINMAP += AX25_APPS_MONITOR|$(AX25_APPS_PREFIX)/usr/sbin/ax25mond
BINMAP += DIREWOLF|$(DIREWOLF_PREFIX)/usr/bin/direwolf

# --------------------------------------------------------------------

bar := |

define _split
$(word $(1),$(subst $(bar), ,$(2)))
endef

MODULE_TARGETS :=
BUILD_TARGETS  :=
COPY_BINS      :=
AX25_TOOLS_BINS :=
AX25_APPS_BINS  :=

define ProcessFeature
$(if $(filter y,$(CONFIG_$(call _split,1,$(1)))), \
  $(eval MODULE_TARGETS += $(call _split,2,$(1))) \
  $(eval BUILD_TARGETS  += $(call _split,3,$(1))))
endef

define ProcessBin
$(eval __flag := $(call _split,1,$(1)))
$(eval __path := $(call _split,2,$(1)))
$(if $(filter y,$(CONFIG_$(__flag))), \
  $(if $(filter AX25_TOOLS_%,$(__flag)), \
       $(eval AX25_TOOLS_BINS += $(__path)), \
       $(if $(filter AX25_APPS_%,$(__flag)), \
            $(eval AX25_APPS_BINS += $(__path)), \
            $(eval COPY_BINS      += $(__path)))))
endef

$(foreach f,$(FEATURES),$(call ProcessFeature,$f))
$(foreach b,$(BINMAP)   ,$(call ProcessBin,$b))

#TODO: add to features
ifeq ($(CONFIG_DIREWOLF),y)
BUILD_TARGETS += direwolf
endif

AX25_MODULES        := $(filter ax25-%,$(MODULE_TARGETS))
AX25_TOOLS_BINARIES := $(notdir $(AX25_TOOLS_BINS))
AX25_APPS_BINARIES  := $(notdir $(AX25_APPS_BINS))

# --------------------------------------------------------------------

MODMAP := \
  HAM          modules/ham.modlist          \
  USB          modules/usb.modlist          \
  USB_STORAGE  modules/usb-storage.modlist  \
  FS           modules/fs.modlist           \
  OVERLAY_FS   modules/overlay-fs.modlist   \
  NET          modules/network.modlist      \
  SOUND        modules/sound.modlist

$(foreach m,$(MODMAP),\
  $(if $(filter y,$(CONFIG_$(word 1,$(m)))),$(eval DISTRO_MODLISTS += $(word 2,$(m)))))

MODSRC := $(BUILD)
MODDST := "$(INITROOT)/lib/modules/$(KERNEL_VERSION)"

# --------------------------------------------------------------------

.PHONY: all extras run clean distclean iso \
        ax25 ax25-lib ax25-tools ax25-tools-build ax25-apps ax25-apps-build \
        ncurses-install direwolf direwolf-build direwolf-patch direwolf-download \
        clean-distro

all: kernel busybox
extras: $(MODULE_TARGETS) $(BUILD_TARGETS)

.PHONY: dbg-vars
dbg-vars:
	@echo "MODULE_TARGETS  = $(MODULE_TARGETS)"
	@echo "BUILD_TARGETS   = $(BUILD_TARGETS)"
	@echo "COPY_BINS       = $(COPY_BINS)"
	@echo "AX25_TOOLS_BINS = $(AX25_TOOLS_BINS)"
	@echo "AX25_APPS_BINS  = $(AX25_APPS_BINS)"
	$(info RAW="$(CONFIG_LIB_AX25)")

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

$(KERNEL_BUILD)/arch/x86/boot/bzImage: modules/base/kernel.config $(KERNEL_SRC)/.prepared
	@mkdir -p $(KERNEL_BUILD)
	$(MAKE) -C $(KERNEL_SRC) mrproper
	cp modules/base/kernel.config $(KERNEL_BUILD)/.config
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) olddefconfig
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) bzImage modules
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) \
	        INSTALL_HDR_PATH=$(LINUX_HEADERS_DIR) headers_install

# --------------------------------------------------------------------

busybox: $(INITROOT)/bin/busybox

$(BUSYBOX_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(BUSYBOX_URL) -o $(SOURCES)/$(BUSYBOX_TARBALL)
	tar -xf $(BUSYBOX_TARBALL) -C $(SOURCES)
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
	@for f in $(COPY_BINS) $(AX25_TOOLS_BINS) $(AX25_APPS_BINS); do \
		cp $$f $(INITROOT)/usr/bin/; \
	done
	find $(INITROOT) -type f -perm /a+x -print0 | \
	xargs -0 file -i | awk -F: '/application\/x-executable/{print $$1}' | \
	xargs -r strip --strip-all
	cd $(INITROOT) && find . | cpio -o -H newc --quiet > $(BUILD)/init.cpio

#---------------------------------------------------------------------

$(LIB_AX25_SRC)/.prepared:
	git clone --depth 1 $(LIB_AX25_REPO) $(LIB_AX25_SRC) || true
	@touch $@

$(AX25_TOOLS_SRC)/.prepared:
	git clone --depth 1 $(AX25_TOOLS_REPO) $(AX25_TOOLS_SRC) || true
	@touch $@

$(AX25_APPS_SRC)/.prepared:
	git clone --depth 1 $(AX25_APPS_REPO) $(AX25_APPS_SRC) || true
	@touch $@


ax25: $(AX25_MODULES)

ax25-lib: $(LIB_AX25_SRC)/.prepared
	@mkdir -p $(LIB_AX25_PREFIX)
	cd $(LIB_AX25_SRC) && autoreconf -fi
	cd $(LIB_AX25_SRC) && CFLAGS="-Os" LDFLAGS="-s" ./configure --prefix=/usr --enable-static
	$(MAKE) -C $(LIB_AX25_SRC)
	$(MAKE) -C $(LIB_AX25_SRC) DESTDIR=$(LIB_AX25_PREFIX) install

ax25-tools: ax25-tools-build
	@for bin in $(AX25_TOOLS_BINARIES); do \
	  found=$$(find $(AX25_TOOLS_PREFIX) -type f -name $$bin); \
	  if [ -n "$$found" ]; then cp $$found $(AX25_TOOLS_INITROOT)/; else exit 1; fi; \
	done

ax25-tools-build: ax25-lib $(AX25_TOOLS_SRC)/.prepared
	@mkdir -p $(AX25_TOOLS_PREFIX)
	cd $(AX25_TOOLS_SRC) && libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	cd $(AX25_TOOLS_SRC) && CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib -static" CFLAGS="-Os" ./configure --prefix=/usr --enable-static --without-x
	$(MAKE) -C $(AX25_TOOLS_SRC)
	$(MAKE) -C $(AX25_TOOLS_SRC) DESTDIR=$(AX25_TOOLS_PREFIX) install
	@mkdir -p $(AX25_TOOLS_INITROOT)

ax25-apps: ax25-apps-build
	@for bin in $(AX25_APPS_BINARIES); do \
	  found=$$(find $(AX25_APPS_PREFIX) -type f -name $$bin); \
	  if [ -n "$$found" ]; then cp $$found $(AX25_APPS_INITROOT)/; else exit 1; fi; \
	done

ax25-apps-build: ax25-tools ncurses-install $(AX25_APPS_SRC)/.prepared
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

ncurses-install: $(NCURSES_LIB)
$(NCURSES_LIB): $(NCURSES_SRC)/.prepared
	cd $(NCURSES_SRC) && make distclean || true
	cd $(NCURSES_SRC) && ./configure --prefix=/usr --enable-widec --enable-static --disable-shared --with-normal --without-debug
	cd $(NCURSES_SRC) && make -j$$(nproc)
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(NCURSES_PREFIX)

#---------------------------------------------------------------------

$(DIREWOLF_SRC)/.prepared:
	git clone --depth 1 $(DIREWOLF_REPO) $(DIREWOLF_SRC) || true
	@touch $@

direwolf-download: $(DIREWOLF_SRC)/.prepared

direwolf-patch: direwolf-download
	cd $(DIREWOLF_SRC) && git clean -fdx && git reset --hard
	cd $(DIREWOLF_SRC) && mkdir -p build
	cd $(DIREWOLF_SRC) && patch -p0 < $(abspath $(DIREWOLF_CMAKE_PATCH)) || true
	cd $(DIREWOLF_SRC)/src && patch -p0 < $(abspath $(DIREWOLF_SRC_CMAKE_PATCH)) || true

direwolf-build: direwolf-patch libudev-zero-install alsa-install
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
	cd $(DIREWOLF_SRC) && make -j$$(nproc)

direwolf: direwolf-build
	@mkdir -p $(DIREWOLF_PREFIX)
	cd $(DIREWOLF_SRC) && make DESTDIR=$(DIREWOLF_PREFIX) install
	strip $(DIREWOLF_PREFIX)/usr/bin/direwolf
	@mkdir -p $(INITROOT)/usr/bin
	cp $(DIREWOLF_PREFIX)/usr/bin/direwolf $(INITROOT)/usr/bin

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

distclean:
	$(MAKE) -C $(SOURCES)/busybox O=$(BUSYBOX_BUILD) distclean
	$(MAKE) -C $(SOURCES)/linux  O=$(KERNEL_BUILD)  distclean
