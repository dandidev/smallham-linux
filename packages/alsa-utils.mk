SOURCES            ?= /opt/smallest_linux_ham/sources
BUILD              ?= /opt/smallest_linux_ham/build
LINUX_HEADERS_DIR  ?= /opt/smallest_linux_ham/toolchain/linux-headers
ALSA_PREFIX        ?= /opt/smallest_linux_ham/toolchain/alsa
MUSL_PATH          ?= /opt/smallest_linux_ham/toolchain/musl

CC := $(MUSL_PATH)/bin/musl-gcc
#CFLAGS := -Os -static -I$(LINUX_HEADERS_DIR)/include -I$(ALSA_PREFIX)/usr/include -I$(ALSA_UTILS_SRC)/include -fno-pie -fno-plt
CFLAGS := -Os -static -I$(LINUX_HEADERS_DIR)/include -I$(ALSA_PREFIX)/usr/include -I$(ALSA_UTILS_SRC)/include -I$(ALSA_UTILS_SRC) -fno-pie -fno-plt
LDFLAGS := -L$(ALSA_PREFIX)/usr/lib -lasound -lm -lpthread -static

ALSA_UTILS_VERSION  := 1.2.14
ALSA_UTILS_TARBALL  := alsa-utils-$(ALSA_UTILS_VERSION).tar.bz2
ALSA_UTILS_URL      := https://www.alsa-project.org/files/pub/utils/$(ALSA_UTILS_TARBALL)
ALSA_UTILS_SRC      := $(SOURCES)/alsa-utils-$(ALSA_UTILS_VERSION)
ALSA_UTILS_PREFIX   := $(BUILD)/alsa-utils

#----------------|-KCONFIG VAR-----|GOAL NAME---------
PKG_FEATURES 	+= ALSA_UTILS_APLAY|alsa-utils

#----------------|-KCONFIG VAR-----|BINARYs PATH-----------------------
PKG_BINS 		+= ALSA_UTILS_APLAY|$(ALSA_UTILS_PREFIX)/usr/bin/aplay

# ---------------------------------------------------------------
$(ALSA_UTILS_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(ALSA_UTILS_URL) -o $(SOURCES)/$(ALSA_UTILS_TARBALL)
	tar -xf $(SOURCES)/$(ALSA_UTILS_TARBALL) -C $(SOURCES)
	@touch $@

# ---------------------------------------------------------------
alsa-utils: $(ALSA_UTILS_SRC)/.prepared $(ALSA_UTILS_SRC)/aplay/aplay.o
	@mkdir -p $(ALSA_UTILS_PREFIX)/usr/bin
	$(CC) -o $(ALSA_UTILS_PREFIX)/usr/bin/aplay \
		$(ALSA_UTILS_SRC)/aplay/aplay.o \
		$(LDFLAGS)

# ---------------------------------------------------------------
$(ALSA_UTILS_SRC)/aplay/aplay.o: $(ALSA_UTILS_SRC)/aplay/aplay.c
	cd $(ALSA_UTILS_SRC) && \
		./configure --prefix=/usr --disable-alsamixer --disable-alsaloop --disable-xmlto --disable-nls
	$(CC) $(CFLAGS) \
		-I$(ALSA_UTILS_SRC)/include \
		-I$(ALSA_UTILS_SRC) \
		-c -o $@ $<

# ---------------------------------------------------------------
clean:
	rm -rf $(ALSA_UTILS_SRC) $(SOURCES)/$(ALSA_UTILS_TARBALL) $(ALSA_UTILS_PREFIX)