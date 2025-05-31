ifndef INCLUDED_NCURSES_MK
INCLUDED_NCURSES_MK := 1

NCURSES_VERSION := 6.4
NCURSES_TARBALL := ncurses-$(NCURSES_VERSION).tar.gz
NCURSES_URL := https://ftp.gnu.org/pub/gnu/ncurses/$(NCURSES_TARBALL)
NCURSES_SRC := $(SOURCES)/ncurses-$(NCURSES_VERSION)
NCURSES_PREFIX := $(PREFIX)/ncurses

#---------------------------------------------------------------------

$(NCURSES_SRC)/.prepared:
	@mkdir -p $(SOURCES)
	curl -L $(NCURSES_URL) | tar xz -C $(SOURCES)
	@touch $@

$(NCURSES_PREFIX)/.installed: $(NCURSES_SRC)/.prepared
#	cd $(NCURSES_SRC) && make distclean || true
	cd $(NCURSES_SRC) && ./configure --prefix=/usr --enable-widec --enable-static --disable-shared --with-normal --without-debug
	cd $(NCURSES_SRC) && make
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(NCURSES_PREFIX)
	@touch $@

ncurses: $(NCURSES_PREFIX)/.installed

endif