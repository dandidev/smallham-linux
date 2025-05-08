SOURCE_DIR := sources
TOOLCHAIN := $(abspath toolchain)

ALSA_VERSION := 1.2.3.2
ALSA_TARBALL := alsa-lib-$(ALSA_VERSION).tar.bz2
ALSA_URL := https://www.alsa-project.org/files/pub/lib/$(ALSA_TARBALL)
ALSA_SRC := $(SOURCE_DIR)/alsa-lib-$(ALSA_VERSION)
ALSA_PREFIX := $(TOOLCHAIN)/alsa

.PHONY: alsa-install

alsa-install: musl-install
	@echo ">>> Building ALSA v$(ALSA_VERSION)"
	@if [ ! -d "$(ALSA_SRC)" ]; then \
		mkdir -p $(SOURCE_DIR); \
		curl -L $(ALSA_URL) -o $(SOURCE_DIR)/$(ALSA_TARBALL); \
		tar xjf $(SOURCE_DIR)/$(ALSA_TARBALL) -C $(SOURCE_DIR); \
	fi
	cd $(ALSA_SRC) && CC=$(MUSL_CC) ./configure \
		--prefix=/usr \
		--enable-static \
		--disable-shared \
		--disable-python \
		--disable-aload \
		--disable-topology \
		--disable-ucm \
		--disable-mixer \
		--disable-old-symbols \
		--disable-debug \
		CFLAGS="-Os -ffunction-sections -fdata-sections -I$(TOOLCHAIN)/linux-headers/include" \
		LDFLAGS="-Wl,--gc-sections"
	cd $(ALSA_SRC) && make -j$$(nproc)
	cd $(ALSA_SRC) && make DESTDIR=$(ALSA_PREFIX) install


MUSL_VERSION := 1.2.4
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_SRC := $(SOURCE_DIR)/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(TOOLCHAIN)/musl

.PHONY: musl-install

musl-install:
	@echo ">>> Building MUSL $(MUSL_VERSION)"
	@if [ ! -d "$(SOURCE_DIR)" ]; then mkdir -p $(SOURCE_DIR); fi
	@if [ ! -f "$(SOURCE_DIR)/$(MUSL_TARBALL)" ]; then \
		curl -L $(MUSL_URL) -o $(SOURCE_DIR)/$(MUSL_TARBALL); \
	fi
	@if [ ! -d "$(MUSL_SRC)" ]; then \
		tar -xzf $(SOURCE_DIR)/$(MUSL_TARBALL) -C $(SOURCE_DIR); \
	fi

	cd $(MUSL_SRC) && make distclean || true
	cd $(MUSL_SRC) && ./configure --prefix=$(MUSL_PREFIX)
	cd $(MUSL_SRC) && make -j$$(nproc)
	cd $(MUSL_SRC) && make install

export MUSL_PREFIX := $(MUSL_PREFIX)
export MUSL_CC := $(MUSL_PREFIX)/bin/musl-gcc


LIBUDEVZERO_VERSION := 1.0.3
LIBUDEVZERO_TARBALL := libudev-zero-$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_URL := https://github.com/illiliti/libudev-zero/archive/refs/tags/$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_SRC := $(SOURCE_DIR)/libudev-zero-$(LIBUDEVZERO_VERSION)
LIBUDEVZERO_PREFIX := $(TOOLCHAIN)/libudev-zero

.PHONY: libudev-zero-install

libudev-zero-install:
	@echo ">>> Building libudev-zero v$(LIBUDEVZERO_VERSION)"
	@if [ ! -d "$(LIBUDEVZERO_SRC)" ]; then \
		mkdir -p $(SOURCE_DIR); \
		curl -L $(LIBUDEVZERO_URL) -o $(SOURCE_DIR)/$(LIBUDEVZERO_TARBALL); \
		tar xzf $(SOURCE_DIR)/$(LIBUDEVZERO_TARBALL) -C $(SOURCE_DIR); \
	fi
	cd $(LIBUDEVZERO_SRC) && LDFLAGS="-s" make
	cd $(LIBUDEVZERO_SRC) && make PREFIX=$(LIBUDEVZERO_PREFIX)/usr install
