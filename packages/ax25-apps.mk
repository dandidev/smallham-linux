ifndef INCLUDED_AX25_APPS_MK
INCLUDED_AX25_APPS_MK := 1

include packages/ncurses.mk
include packages/lib-ax25.mk

AX25_APPS_REPO := https://github.com/dandidev/ax25-apps.git
# Pinned, so a release can be rebuilt from the same source.
AX25_APPS_COMMIT := 1c49152fa5e85bbf586690468ea22a1ae087bf6d
AX25_APPS_SRC := $(SOURCES)/ax25-apps
AX25_APPS_PREFIX := $(BUILD)/ax25-apps
AX25_APPS_PREPARED := $(STAMP)/ax25-apps.prepared
AX25_APPS_INSTALLED := $(STAMP)/ax25-apps.installed

# _GNU_SOURCE: see ax25-tools.mk
AX25_APPS_CPPFLAGS := "-D_GNU_SOURCE -I$(LIB_AX25_PREFIX)/usr/include -I$(NCURSES_PREFIX)/usr/include -I$(LINUX_HEADERS_DIR)/include"
AX25_APPS_LDFLAGS := "-L$(LIB_AX25_PREFIX)/usr/lib -L$(NCURSES_PREFIX)/usr/lib -static"
# see ax25-tools.mk
AX25_APPS_CFLAGS := "-Os -Wno-error=incompatible-pointer-types"

# --------------------------------------------------------------------

PKG_FEATURES += AX25_APPS|ax25-apps

PKG_BINS += AX25_APPS_CALL|$(AX25_APPS_PREFIX)/usr/bin/call
PKG_BINS += AX25_APPS_LISTEN|$(AX25_APPS_PREFIX)/usr/bin/listen
PKG_BINS += AX25_APPS_IPD|$(AX25_APPS_PREFIX)/usr/sbin/ax25ipd

# --------------------------------------------------------------------

$(AX25_APPS_PREPARED):
	rm -rf $(AX25_APPS_SRC)
	git init -q $(AX25_APPS_SRC)
	cd $(AX25_APPS_SRC) && git fetch -q --depth 1 $(AX25_APPS_REPO) $(AX25_APPS_COMMIT) && \
		git checkout -q FETCH_HEAD
	@touch $@

$(AX25_APPS_INSTALLED): ax25-tools ncurses $(AX25_APPS_PREPARED) | musl
	rm -rf $(AX25_APPS_PREFIX)
	@mkdir -p $(AX25_APPS_PREFIX)
	cd $(AX25_APPS_SRC) && git checkout -- . && git clean -fdxq && \
		git apply $(abspath patches/ax25-apps-termio.patch) $(abspath patches/ax25-apps-musl.patch)
	cd $(AX25_APPS_SRC) && autoreconf --install --force
	cd $(AX25_APPS_SRC) && \
		CC=$(MUSL_CC) \
		CPPFLAGS=$(AX25_APPS_CPPFLAGS) \
		LDFLAGS=$(AX25_APPS_LDFLAGS) \
		CFLAGS=$(AX25_APPS_CFLAGS) \
		./configure --prefix=/usr --enable-static
	$(MAKE) -C $(AX25_APPS_SRC)
	$(MAKE) -C $(AX25_APPS_SRC) DESTDIR=$(AX25_APPS_PREFIX) install
	@touch $@

ax25-apps: $(AX25_APPS_INSTALLED)

ax25-apps-clean:
	rm -rf $(AX25_APPS_SRC) $(AX25_APPS_PREFIX) $(AX25_APPS_PREPARED) $(AX25_APPS_INSTALLED)

endif