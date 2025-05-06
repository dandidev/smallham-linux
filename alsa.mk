include musl.mk

SOURCE_DIR := sources
ALSA_VERSION := 1.2.10
ALSA_TARBALL := alsa-lib-$(ALSA_VERSION).tar.bz2
ALSA_URL := https://www.alsa-project.org/files/pub/lib/$(ALSA_TARBALL)
ALSA_SRC := $(SOURCE_DIR)/alsa-lib-$(ALSA_VERSION)
ALSA_PREFIX := $(abspath toolchain/alsa-lib)
ALSA_LIB := $(ALSA_PREFIX)/usr/lib/libasound.o

INITROOT := $(abspath build/current/initroot)

.PHONY: alsa-download alsa-install

alsa-download:
	@echo ">>> Downloading Alsa-lib $(ALSA_VERSION)"
	@mkdir -p sources
	@if [ ! -f sources/$(ALSA_TARBALL) ]; then \
		curl -L $(ALSA_URL) -o sources/$(ALSA_TARBALL); \
	else \
		echo ">>> Alsa-lib tarball already exists."; \
	fi
	@if [ ! -d "$(ALSA_SRC)" ]; then \
		tar -xf sources/$(ALSA_TARBALL) -C sources; \
	else \
		echo ">>> Alsa-lib source already unpacked."; \
	fi

alsa-install: alsa-download musl-install
	@echo ">>> Building static ALSA library"

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
		CFLAGS="-Os -ffunction-sections -fdata-sections -I$(TOOLCHAIN_DIR)/linux-headers/include" \
		LDFLAGS="-Wl,--gc-sections"

	cd $(ALSA_SRC) && make -j$$(nproc)
	cd $(ALSA_SRC) && make install DESTDIR=$(ALSA_PREFIX)
	
	cd $(ALSA_PREFIX) && cp usr/share $(INITROOT)/usr


$(ALSA_LIB): alsa-install

alsa: $(ALSA_LIB) 
