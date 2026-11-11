ifndef INCLUDED_ALSA_LIB_MK
INCLUDED_ALSA_LIB_MK := 1

include packages/musl.mk

ALSA_LIB_VERSION := 1.2.14
ALSA_LIB_TARBALL := alsa-lib-$(ALSA_LIB_VERSION).tar.bz2
ALSA_LIB_URL := https://www.alsa-project.org/files/pub/lib/$(ALSA_LIB_TARBALL)
ALSA_LIB_SRC := $(SOURCES)/alsa-lib-$(ALSA_LIB_VERSION)
ALSA_LIB_PREFIX := $(PREFIX)/alsa
ALSA_LIB_PREPARED := $(STAMP)/alsa-lib.prepared
ALSA_LIB_INSTALLED := $(STAMP)/alsa-lib.installed

ALSA_LIB_CFLAGS := "-Os -ffunction-sections -fdata-sections -I$(LINUX_HEADERS_DIR)/include"
ALSA_LIB_LDFLAGS := "-Wl,--gc-sections"

# ALSA configuration: without /usr/share/alsa/alsa.conf no audio device can be opened
PKG_DIRS += DIREWOLF|$(ALSA_LIB_PREFIX)/usr/share/alsa:/usr/share/alsa
PKG_DIRS += ALSA_UTILS_APLAY|$(ALSA_LIB_PREFIX)/usr/share/alsa:/usr/share/alsa

#---------------------------------------------------------------------

$(ALSA_LIB_PREPARED):
	curl -L $(ALSA_LIB_URL) -o $(SOURCES)/$(ALSA_LIB_TARBALL);
	tar xjf $(SOURCES)/$(ALSA_LIB_TARBALL) -C $(SOURCES);
	@touch $@

$(ALSA_LIB_INSTALLED): $(ALSA_LIB_PREPARED) | musl
	cd $(ALSA_LIB_SRC) && CC=$(MUSL_CC) ./configure \
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
	@touch $@

alsa-lib: $(ALSA_LIB_INSTALLED)

alsa-lib-clean:
	rm -rf $(ALSA_LIB_SRC) $(SOURCES)/$(ALSA_LIB_TARBALL) $(ALSA_LIB_PREFIX) $(ALSA_LIB_PREPARED) $(ALSA_LIB_INSTALLED)

endif