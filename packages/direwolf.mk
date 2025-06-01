ifndef INCLUDED_DIREWOLF_MK
INCLUDED_DIREWOLF_MK := 1

include packages/alsa-lib.mk
include packages/libudevzero.mk

DIREWOLF_REPO := https://github.com/wb2osz/direwolf.git
DIREWOLF_SRC := $(SOURCES)/direwolf
DIREWOLF_PREFIX := $(BUILD)/direwolf
DIREWOLF_CMAKE_PATCH := patches/direwolf-cmakelists.patch
DIREWOLF_SRC_CMAKE_PATCH := patches/direwolf-src-cmakelists.patch
DIREWOLF_PREPARED := $(STAMP)/direwolf.prepared
DIREWOLF_INSTALLED := $(STAMP)/direwolf.installed
DIREWOLF_PATCHED := $(STAMP)/direwolf.patched

DIREWOLF_CMAKE_C_FLAGS := "-Os -ffunction-sections -fdata-sections -isystem $(LINUX_HEADERS_DIR)/include -I$(ALSA_LIB_PREFIX)/usr/include -I$(LIBUDEVZERO_PREFIX)/usr/include"
DIREWOLF_CMAKE_EXE_LINKER_FLAGS := "-Wl,--whole-archive $(ALSA_LIB_PREFIX)/usr/lib/libasound.a $(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a -Wl,--no-whole-archive -static"

#---------------------------------------------------------------------

PKG_FEATURES += DIREWOLF|direwolf

PKG_BINS += DIREWOLF|$(DIREWOLF_PREFIX)/usr/bin/direwolf

#---------------------------------------------------------------------

$(DIREWOLF_PREPARED):
	git clone --depth 1 $(DIREWOLF_REPO) $(DIREWOLF_SRC) || true
	@touch $@

$(DIREWOLF_PATCHED): $(DIREWOLF_PREPARED)
	cd $(DIREWOLF_SRC) && git clean -fdx && git reset --hard
	cd $(DIREWOLF_SRC) && mkdir -p build
	cd $(DIREWOLF_SRC) && patch -p0 < $(abspath $(DIREWOLF_CMAKE_PATCH)) || true
	cd $(DIREWOLF_SRC)/src && patch -p0 < $(abspath $(DIREWOLF_SRC_CMAKE_PATCH)) || true
	@touch $@

$(DIREWOLF_INSTALLED): $(DIREWOLF_PATCHED) libudev-zero alsa-lib
	cd $(DIREWOLF_SRC) && cmake \
	  -DCMAKE_SYSTEM_NAME=smallham-linux \
	  -DEXTERNAL_ALSA_LIB=$(ALSA_LIB_PREFIX)/usr/lib/libasound.a \
	  -DEXTERNAL_UDEV_LIB=$(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a \
	  -DCMAKE_INSTALL_PREFIX=/usr \
	  -DINSTALL_BIN_DIR=/usr/bin \
	  -DCMAKE_BUILD_TYPE=MinSizeRel \
	  -DCMAKE_C_COMPILER=$(MUSL_CC) \
	  -DCMAKE_FIND_ROOT_PATH=$(PREFIX) \
	  -DCMAKE_C_FLAGS=$(DIREWOLF_CMAKE_C_FLAGS) \
	  -DCMAKE_EXE_LINKER_FLAGS=$(DIREWOLF_CMAKE_EXE_LINKER_FLAGS)
	cd $(DIREWOLF_SRC) && make
	@mkdir -p $(DIREWOLF_PREFIX)
	cd $(DIREWOLF_SRC) && make DESTDIR=$(DIREWOLF_PREFIX) install
#	strip $(DIREWOLF_PREFIX)/usr/bin/direwolf
#	@mkdir -p $(INITROOT)/usr/bin
#	cp $(DIREWOLF_PREFIX)/usr/bin/direwolf $(INITROOT)/usr/bin
	@touch $@

direwolf: $(DIREWOLF_INSTALLED)

direwolf-clean:
	rm -rf $(DIREWOLF_SRC) $(DIREWOLF_PREFIX) $(DIREWOLF_PREPARED) $(DIREWOLF_INSTALLED) $(DIREWOLF_PATCHED)

endif