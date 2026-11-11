ifndef INCLUDED_AX25_TOOLS_MK
INCLUDED_AX25_TOOLS_MK := 1

include packages/lib-ax25.mk

AX25_TOOLS_REPO := https://github.com/dandidev/ax25-tools.git
AX25_TOOLS_SRC := $(SOURCES)/ax25-tools
AX25_TOOLS_PREFIX := $(BUILD)/ax25-tools
AX25_TOOLS_PREPARED := $(STAMP)/ax25-tools.prepared
AX25_TOOLS_INSTALLED := $(STAMP)/ax25-tools.installed

# _GNU_SOURCE: musl defines BSD types (caddr_t, ...) only on request
AX25_TOOLS_CPPFLAGS := "-D_GNU_SOURCE -I$(LIB_AX25_PREFIX)/usr/include -I$(LINUX_HEADERS_DIR)/include"
AX25_TOOLS_LDFLAGS := "-L$(LIB_AX25_PREFIX)/usr/lib -static"
# musl declares sockaddr arguments as plain struct sockaddr * (glibc uses a
# transparent union), the old code passes sockaddr_in * etc. without a cast
AX25_TOOLS_CFLAGS := "-Os -Wno-error=incompatible-pointer-types"

# --------------------------------------------------------------------

PKG_FEATURES += AX25_TOOLS|ax25-tools

PKG_BINS += AX25_TOOLS_NETROMD|$(AX25_TOOLS_PREFIX)/usr/sbin/netromd
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissattach
PKG_BINS += AX25_TOOLS_KISS|$(AX25_TOOLS_PREFIX)/usr/sbin/kissparms

# --------------------------------------------------------------------

$(AX25_TOOLS_PREPARED):
	git clone --depth 1 $(AX25_TOOLS_REPO) $(AX25_TOOLS_SRC) || true
	@touch $@

# Only the subdirectories with programs selectable in Kconfig are built.
# The others (tcpip, dmascc, yamdrv, ...) are legacy hardware/gateway tools,
# and some of them do not compile with musl (e.g. <protocols/talkd.h>).
AX25_TOOLS_SUBDIRS := ax25 kiss netrom

$(AX25_TOOLS_INSTALLED): lib-ax25 $(AX25_TOOLS_PREPARED) | musl ncurses
	rm -rf $(AX25_TOOLS_PREFIX)
	@mkdir -p $(AX25_TOOLS_PREFIX)
	cd $(AX25_TOOLS_SRC) && git checkout -q -- . && git clean -fdxq
	sed -i 's/^SUBDIRS = .*/SUBDIRS = $(AX25_TOOLS_SUBDIRS)/' $(AX25_TOOLS_SRC)/Makefile.am
	cd $(AX25_TOOLS_SRC) && libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	cd $(AX25_TOOLS_SRC) && \
		CC=$(MUSL_CC) \
		CPPFLAGS=$(AX25_TOOLS_CPPFLAGS) \
		LDFLAGS=$(AX25_TOOLS_LDFLAGS) \
		CFLAGS=$(AX25_TOOLS_CFLAGS) \
		./configure --prefix=/usr --without-x ac_cv_header_zlib_h=no
	$(MAKE) -C $(AX25_TOOLS_SRC)
	$(MAKE) -C $(AX25_TOOLS_SRC) DESTDIR=$(AX25_TOOLS_PREFIX) install
	@touch $@

ax25-tools: $(AX25_TOOLS_INSTALLED)

ax25-tools-clean:
	rm -rf $(AX25_TOOLS_SRC) $(AX25_TOOLS_PREFIX) $(AX25_TOOLS_PREPARED) $(AX25_TOOLS_INSTALLED)

endif