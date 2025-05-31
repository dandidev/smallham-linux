ifndef INCLUDED_ALSA_LIB_MK
INCLUDED_ALSA_LIB_MK := 1

ALSA_LIB_VERSION := 1.2.14
ALSA_LIB_TARBALL := alsa-lib-$(ALSA_LIB_VERSION).tar.bz2
ALSA_LIB_URL := https://www.alsa-project.org/files/pub/lib/$(ALSA_LIB_TARBALL)
ALSA_LIB_SRC := $(SOURCES)/alsa-lib-$(ALSA_LIB_VERSION)
ALSA_LIB_PREFIX := $(PREFIX)/alsa

CC := $(MUSL_PATH)/bin/musl-gcc
ALSA_LIB_CFLAGS := "-Os -ffunction-sections -fdata-sections -I$(LINUX_HEADERS_DIR)/include"
ALSA_LIB_LDFLAGS := "-Wl,--gc-sections"

#---------------------------------------------------------------------

$(ALSA_LIB_SRC)/.prepared:
	curl -L $(ALSA_LIB_URL) -o $(SOURCES)/$(ALSA_LIB_TARBALL);
	tar xjf $(SOURCES)/$(ALSA_LIB_TARBALL) -C $(SOURCES);
	@touch $@

alsa-lib: $(ALSA_LIB_SRC)/.prepared musl
	cd $(ALSA_LIB_SRC) && CC=$(CC) ./configure \
		--prefix=/usr \
		--enable-static \
		--disable-shared \
		--disable-python \
		--disable-aload \
		--disable-ucm \
		--disable-mixer \
		--disable-old-symbols \
		CFLAGS=$(ALSA_LIB_CFLAGS) \
		LDFLAGS=$(ALSA_LIB_LDFLAGS)
	cd $(ALSA_LIB_SRC) && make
	cd $(ALSA_LIB_SRC) && make DESTDIR=$(ALSA_LIB_PREFIX) install

endif