ifndef INCLUDED_ALSA_UTILS_MK
INCLUDED_ALSA_UTILS_MK := 1

include packages/musl.mk

ALSA_UTILS_VERSION  := 1.2.14
ALSA_UTILS_TARBALL  := alsa-utils-$(ALSA_UTILS_VERSION).tar.bz2
ALSA_UTILS_URL      := https://www.alsa-project.org/files/pub/utils/$(ALSA_UTILS_TARBALL)
ALSA_UTILS_SRC      := $(SOURCES)/alsa-utils-$(ALSA_UTILS_VERSION)
ALSA_UTILS_PREFIX   := $(BUILD)/alsa-utils
ALSA_UTILS_PREPARED := $(STAMP)/alsa-utils.prepared
ALSA_UTILS_INSTALLED := $(STAMP)/alsa-utils.installed

ALSA_UTILS_CFLAGS := -Os -static -I$(LINUX_HEADERS_DIR)/include -I$(ALSA_PREFIX)/usr/include -I$(ALSA_UTILS_SRC)/include -I$(ALSA_UTILS_SRC) -fno-pie -fno-plt
ALSA_UTILS_LDFLAGS := -L$(ALSA_PREFIX)/usr/lib -lasound -lm -lpthread -static


#----------------|-KCONFIG VAR-----|GOAL NAME---------
PKG_FEATURES 	+= ALSA_UTILS_APLAY|alsa-utils

#----------------|-KCONFIG VAR-----|BINARYs PATH-----------------------
PKG_BINS 		+= ALSA_UTILS_APLAY|$(ALSA_UTILS_PREFIX)/usr/bin/aplay

# ---------------------------------------------------------------
$(ALSA_UTILS_PREPARED):
	@mkdir -p $(SOURCES)
	curl -L $(ALSA_UTILS_URL) -o $(SOURCES)/$(ALSA_UTILS_TARBALL)
	tar -xf $(SOURCES)/$(ALSA_UTILS_TARBALL) -C $(SOURCES)
	@touch $@

# ---------------------------------------------------------------
$(ALSA_UTILS_SRC)/aplay/aplay.o: $(ALSA_UTILS_SRC)/aplay/aplay.c
	cd $(ALSA_UTILS_SRC) && \
		./configure --prefix=/usr --disable-alsamixer --disable-alsaloop --disable-xmlto --disable-nls
	$(MUSL_CC) $(ALSA_UTILS_CFLAGS) -c -o $@ $<

# ---------------------------------------------------------------
alsa-utils: $(ALSA_UTILS_PREPARED) $(ALSA_UTILS_SRC)/aplay/aplay.o
	@mkdir -p $(ALSA_UTILS_PREFIX)/usr/bin
	$(MUSL_CC) -o $(ALSA_UTILS_PREFIX)/usr/bin/aplay \
		$(ALSA_UTILS_SRC)/aplay/aplay.o \
		$(ALSA_UTILS_LDFLAGS)

# ---------------------------------------------------------------

alsa-utils-clean:
	rm -rf $(ALSA_UTILS_SRC) $(SOURCES)/$(ALSA_UTILS_TARBALL) $(ALSA_UTILS_PREFIX) $(ALSA_UTILS_PREPARED) $(ALSA_UTILS_INSTALLED)

endif