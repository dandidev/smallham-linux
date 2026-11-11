ifndef INCLUDED_NCURSES_MK
INCLUDED_NCURSES_MK := 1

NCURSES_VERSION := 6.4
NCURSES_TARBALL := ncurses-$(NCURSES_VERSION).tar.gz
NCURSES_URL := https://ftp.gnu.org/pub/gnu/ncurses/$(NCURSES_TARBALL)
NCURSES_SRC := $(SOURCES)/ncurses-$(NCURSES_VERSION)
NCURSES_PREFIX := $(PREFIX)/ncurses
NCURSES_PREPARED := $(STAMP)/ncurses.prepared
NCURSES_INSTALLED := $(STAMP)/ncurses.installed

#---------------------------------------------------------------------

$(NCURSES_PREPARED):
	@mkdir -p $(SOURCES)
	curl -L $(NCURSES_URL) | tar xz -C $(SOURCES)
	@touch $@

$(NCURSES_INSTALLED): $(NCURSES_PREPARED) | musl kernel-headers
	rm -rf $(NCURSES_PREFIX)
	cd $(NCURSES_SRC) && { make distclean > /dev/null 2>&1 || true; }
	cd $(NCURSES_SRC) && CC=$(MUSL_CC) CFLAGS="-Os" ./configure --prefix=/usr --enable-widec --enable-static --disable-shared --with-normal --without-debug \
	  --without-cxx --without-cxx-binding --without-progs --without-tests --without-manpages
	cd $(NCURSES_SRC) && make
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(NCURSES_PREFIX)
	@touch $@

ncurses: $(NCURSES_INSTALLED)

ncurses-clean:
	rm -rf $(NCURSES_SRC) $(SOURCES)/$(NCURSES_TARBALL) $(NCURSES_PREFIX) $(NCURSES_PREPARED) $(NCURSES_INSTALLED)

endif