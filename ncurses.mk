NCURSES_PREFIX := $(abspath toolchain/ncurses)
NCURSES_VERSION := 6.4
NCURSES_TARBALL := ncurses-$(NCURSES_VERSION).tar.gz
NCURSES_URL := https://ftp.gnu.org/pub/gnu/ncurses/$(NCURSES_TARBALL)
NCURSES_SRC := $(SOURCE_DIR)/ncurses-$(NCURSES_VERSION)
NCURSES_LIB := $(NCURSES_PREFIX)/usr/lib/libncursesw.a

.PHONY: ncurses-install

ncurses-install: $(NCURSES_LIB)

$(NCURSES_LIB):
	@echo ">>> Building and installing system-wide static ncursesw"
	@if [ ! -d "$(NCURSES_SRC)" ]; then \
		mkdir -p $(SOURCE_DIR); \
		curl -L $(NCURSES_URL) | tar xz -C $(SOURCE_DIR); \
	fi

	cd $(NCURSES_SRC) && make distclean || true
	cd $(NCURSES_SRC) && ./configure \
		--prefix=/usr \
		--enable-widec \
		--enable-static \
		--disable-shared \
		--with-normal \
		--without-debug

	cd $(NCURSES_SRC) && make -j$$(nproc)
	cd $(NCURSES_SRC) && make install.libs install.includes DESTDIR=$(abspath toolchain/ncurses)