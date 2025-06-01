ifndef INCLUDED_AX25_TOOLS_MK
INCLUDED_AX25_TOOLS_MK := 1

AX25_TOOLS_REPO := https://github.com/dandidev/ax25-tools.git
AX25_TOOLS_SRC := $(SOURCES)/ax25-tools
AX25_TOOLS_PREFIX := $(BUILD)/ax25-tools
AX25_TOOLS_PREPARED := $(STAMP)/ax25-tools.prepared
AX25_TOOLS_INSTALLED := $(STAMP)/ax25-tools.installed

AX25_TOOLS_CPPFLAGS := "-I$(LIB_AX25_PREFIX)/usr/include" 
AX25_TOOLS_LDFLAGS := "-L$(LIB_AX25_PREFIX)/usr/lib -static"
AX25_TOOLS_CFLAGS := "-Os"

# --------------------------------------------------------------------

PKG_FEATURES += AX25_TOOLS|ax25-tools

PKG_BINS += AX25_TOOLS_NETROMD|$(AX25_TOOLS_PREFIX)/usr/sbin/netromd
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissattach
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissparms

# --------------------------------------------------------------------

$(AX25_TOOLS_PREPARED):
	git clone --depth 1 $(AX25_TOOLS_REPO) $(AX25_TOOLS_SRC) || true
	@touch $@

$(AX25_TOOLS_INSTALLED): lib-ax25 $(AX25_TOOLS_PREPARED) | ncurses
	@mkdir -p $(AX25_TOOLS_PREFIX)
	cd $(AX25_TOOLS_SRC) && libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	cd $(AX25_TOOLS_SRC) && \
		CPPFLAGS=$(AX25_TOOLS_CPPFLAGS) \
		LDFLAGS=$(AX25_TOOLS_LDFLAGS) \
		CFLAGS=$(AX25_TOOLS_CFLAGS) \
		./configure --prefix=/usr --without-x
	$(MAKE) -C $(AX25_TOOLS_SRC)
	$(MAKE) -C $(AX25_TOOLS_SRC) DESTDIR=$(AX25_TOOLS_PREFIX) install
	@touch $@

ax25-tools: $(AX25_TOOLS_INSTALLED)

ax25-tools-clean:
	rm -rf $(AX25_TOOLS_SRC) $(AX25_TOOLS_PREFIX) $(AX25_TOOLS_PREPARED) $(AX25_TOOLS_INSTALLED)

endif