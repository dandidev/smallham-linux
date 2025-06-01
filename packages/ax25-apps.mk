ifndef INCLUDED_AX25_APPS_MK
INCLUDED_AX25_APPS_MK := 1

include packages/ncurses.mk

AX25_APPS_REPO := https://github.com/dandidev/ax25-apps.git
AX25_APPS_SRC := $(SOURCES)/ax25-apps
AX25_APPS_PREFIX := $(BUILD)/ax25-apps
AX25_APPS_INITROOT := $(SQUASHFS_DIR)/usr/bin
AX25_APPS_PREPARED := $(STAMP)/ax25-apps.prepared
AX25_APPS_INSTALLED := $(STAMP)/ax25-apps.installed

AX25_APPS_CPPFLAGS := "-I$(LIB_AX25_PREFIX)/usr/include"
AX25_APPS_LDFLAGS := "-L$(LIB_AX25_PREFIX)/usr/lib -L$(NCURSES_PREFIX)/usr/lib -static"
AX25_APPS_CFLAGS := "-Os"

# --------------------------------------------------------------------

PKG_FEATURES += AX25_APPS|ax25-apps

PKG_BINS += AX25_APPS_CALL|$(AX25_APPS_PREFIX)/usr/bin/call
PKG_BINS += AX25_APPS_LISTEN|$(AX25_APPS_PREFIX)/usr/bin/listen
PKG_BINS += AX25_APPS_IPD|$(AX25_APPS_PREFIX)/usr/sbin/ax25ipd

# --------------------------------------------------------------------

$(AX25_APPS_PREPARED):
	git clone --depth 1 $(AX25_APPS_REPO) $(AX25_APPS_SRC) || true
	@touch $@

$(AX25_APPS_INSTALLED): ax25-tools ncurses $(AX25_APPS_PREPARED)
	@mkdir -p $(AX25_APPS_PREFIX)
	cd $(AX25_APPS_SRC) && autoreconf --install --force
	cd $(AX25_APPS_SRC) && \
		CPPFLAGS=$(AX25_APPS_CPPFLAGS) \
		LDFLAGS=$(AX25_APPS_LDFLAGS) \
		CFLAGS=$(AX25_APPS_CFLAGS) \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(AX25_APPS_SRC)
	$(MAKE) -C $(AX25_APPS_SRC) DESTDIR=$(AX25_APPS_PREFIX) install
	@mkdir -p $(AX25_APPS_INITROOT)
	@touch $@

ax25-apps: $(AX25_APPS_INSTALLED)

ax25-apps-clean:
	rm -rf $(AX25_APPS_SRC) $(AX25_APPS_PREFIX) $(AX25_APPS_PREPARED) $(AX25_APPS_INSTALLED)

endif