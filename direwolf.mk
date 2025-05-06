include alsa.mk
include musl.mk
include libudev-zero.mk

DIREWOLF_REPO := https://github.com/wb2osz/direwolf.git
DIREWOLF_DIR := $(SOURCE_DIR)/direwolf
DIREWOLF_BUILD := $(DIREWOLF_DIR)/build
DIREWOLF_CMAKE_PATCH := $(abspath patches/direwolf-cmakelists.patch)
DIREWOLF_SRC_CMAKE_PATCH := $(abspath patches/direwolf-src-cmakelists.patch)
INITROOT := $(abspath build/current/initroot)

.PHONY: direwolf-install

direwolf-install: alsa libudev-zero-install
	@echo ">>> Building and installing Direwolf"
	@if [ ! -d "$(DIREWOLF_DIR)" ]; then \
		git clone $(DIREWOLF_REPO) $(DIREWOLF_DIR); \
	else \
		echo "Direwolf repo already exists."; \
	fi

	cd $(DIREWOLF_DIR) && git clean -fdx && git reset --hard
	cd $(DIREWOLF_DIR) && mkdir -p build

	cd $(DIREWOLF_DIR) && \
	patch -p0 < $(DIREWOLF_CMAKE_PATCH)

	cd $(DIREWOLF_DIR)/src && \
	patch -p0 < $(DIREWOLF_SRC_CMAKE_PATCH)

	cd $(DIREWOLF_BUILD) && cmake .. \
		-DCMAKE_SYSTEM_NAME=smallham-linux \
		-DEXTERNAL_ALSA_LIB=$(ALSA_PREFIX)/usr/lib/libasound.a \
  		-DEXTERNAL_UDEV_LIB=$(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_C_COMPILER=$(MUSL_CC) \
		-DCMAKE_FIND_ROOT_PATH=/opt/smallest_linux_ham/toolchain \
		-DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -isystem $(LINUX_HEADERS_DIR)/include -I$(ALSA_PREFIX)/usr/include -I$(LIBUDEVZERO_PREFIX)/usr/include" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive $(ALSA_PREFIX)/usr/lib/libasound.a $(LIBUDEVZERO_PREFIX)/usr/lib/libudev.a -Wl,--no-whole-archive -static"

	cd $(DIREWOLF_BUILD) && make
	strip $(DIREWOLF_BUILD)/src/direwolf
	mkdir -p $(INITROOT)/usr/bin
	cp $(DIREWOLF_BUILD)/src/direwolf $(INITROOT)/usr/bin
#	cd $(DIREWOLF_BUILD) && make install DESTDIR=$(INITROOT)