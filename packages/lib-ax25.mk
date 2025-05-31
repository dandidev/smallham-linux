ifndef INCLUDED_LIB_AX25_MK
INCLUDED_LIB_AX25_MK := 1

LIB_AX25_REPO := https://github.com/dandidev/libax25.git
LIB_AX25_SRC := $(SOURCES)/ax25-lib
LIB_AX25_PREFIX := $(PREFIX)/lib-ax25

LIB_AX25_CFLAGS := "-Os -I$(LINUX_HEADERS_DIR)/include"
LIB_AX25_LDFLAGS := "--static"

# --------------------------------------------------------------------

PKG_FEATURES += LIB_AX25|ax25-lib

# --------------------------------------------------------------------

$(LIB_AX25_SRC)/.prepared:
	git clone --depth 1 $(LIB_AX25_REPO) $(LIB_AX25_SRC) || true
	@touch $@

ax25-lib: $(LIB_AX25_SRC)/.prepared | kernel-headers
	@mkdir -p $(LIB_AX25_PREFIX)
	cd $(LIB_AX25_SRC) && autoreconf -fi
	cd $(LIB_AX25_SRC) && \
		CFLAGS=$(LIB_AX25_CFLAGS) \
		LDFLAGS=$(LIB_AX25_LDFLAGS) \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(LIB_AX25_SRC)
	$(MAKE) -C $(LIB_AX25_SRC) DESTDIR=$(LIB_AX25_PREFIX) install

endif