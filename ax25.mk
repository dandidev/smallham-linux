include ncurses.mk
include .config

SOURCE_DIR := sources

LIB_REPO := https://github.com/dandidev/libax25
TOOLS_REPO := https://github.com/dandidev/ax25-tools
APPS_REPO := https://github.com/dandidev/ax25-apps

LIB_DIR := $(SOURCE_DIR)/ax25-lib
TOOLS_DIR := $(SOURCE_DIR)/ax25-tools
APPS_DIR := $(SOURCE_DIR)/ax25-apps

INITROOT := $(abspath build/current/initroot)
LIB_AX25_PREFIX := $(abspath toolchain/lib-ax25)

CONFIG_AX25_APPS_CALL:=y
CONFIG_AX25_TOOLS_NETROMD:=y
CONFIG_AX25_TOOLS_KISS:=y
CONFIG_AX25_APPS_MONITOR:=y

.PHONY: ax25-lib ax25-tools ax25-apps ax25-clean

ax25-lib:
ifeq ($(CONFIG_LIB_AX25),y)
	@echo ">>> Building AX.25 LIB only"
	@if [ ! -d "$(LIB_DIR)" ]; then \
		git clone $(LIB_REPO) $(LIB_DIR); \
	else \
		echo "libax25 already cloned."; \
	fi
	cd $(LIB_DIR) && autoreconf -fi
	cd $(LIB_DIR) && CFLAGS="-Os" LDFLAGS="-s" ./configure --prefix=/usr --enable-static
	cd $(LIB_DIR) && make -j$(nproc)
	cd $(LIB_DIR) && make DESTDIR=$(LIB_AX25_PREFIX) install
endif

ax25-tools: ax25-lib
ifeq ($(CONFIG_LIB_AX25)$(CONFIG_AX25_TOOLS),yy)
	@echo ">>> Building AX.25 TOOLS"
	@if [ ! -d "$(TOOLS_DIR)" ]; then \
		git clone $(TOOLS_REPO) $(TOOLS_DIR); \
	else \
		echo "ax25-tools already cloned."; \
	fi
	cd $(TOOLS_DIR) && libtoolize --force --copy && aclocal && autoheader && automake --add-missing && autoconf
	cd $(TOOLS_DIR) && CFLAGS="-Os" LDFLAGS="-s" ./configure \
		--prefix=/usr \
		--without-x \
		CPPFLAGS="-I$(LIB_AX25_PREFIX)/usr/include" \
		LDFLAGS="-L$(LIB_AX25_PREFIX)/usr/lib"
#	cd $(TOOLS_DIR) && make LDFLAGS="-static" -j$(nproc)
#	cd $(TOOLS_DIR) && make DESTDIR=$(INITROOT) install
ifeq ($(CONFIG_AX25_TOOLS_NETROMD),y)
	@echo ">>> Building netromd (from ax25-tools/netrom)"
	$(MAKE) -C $(TOOLS_DIR)/netrom LDFLAGS="-static"
	mkdir -p $(INITROOT)/usr/sbin
	strip $(TOOLS_DIR)/netrom/netromd
	strip $(TOOLS_DIR)/netrom/nrattach
	cp $(TOOLS_DIR)/netrom/netromd $(INITROOT)/usr/sbin/
	cp $(TOOLS_DIR)/netrom/nrattach $(INITROOT)/usr/sbin/
endif
ifeq ($(CONFIG_AX25_TOOLS_KISS),y)
	@echo ">>> Building kiss (from ax25-tools/kiss)"
	$(MAKE) -C $(TOOLS_DIR)/kiss LDFLAGS="-static"
	mkdir -p $(INITROOT)/usr/sbin
	strip $(TOOLS_DIR)/kiss/kissattach
	strip $(TOOLS_DIR)/kiss/kissparms
	cp $(TOOLS_DIR)/kiss/kissattach $(INITROOT)/usr/sbin/
	cp $(TOOLS_DIR)/kiss/kissparms $(INITROOT)/usr/sbin/
endif

endif

ax25-apps: ncurses-install ax25-tools
ifeq ($(CONFIG_LIB_AX25)$(CONFIG_AX25_TOOLS)$(CONFIG_AX25_APPS),yyy)
	@echo ">>> Building AX.25 APPS"
	@if [ ! -d "$(APPS_DIR)" ]; then \
		git clone $(APPS_REPO) $(APPS_DIR); \
	else \
		echo "ax25-apps already cloned."; \
	fi
	cd $(APPS_DIR) && autoreconf --install --force
	cd $(APPS_DIR) && ./configure \
		--prefix=/usr \
		--sysconfdir=/etc \
		CFLAGS="-Os" \
		CPPFLAGS="-I$(INITROOT)/usr/include -I$(NCURSES_PREFIX)/usr/include -D_XOPEN_SOURCE=600 -D_DEFAULT_SOURCE"  \
		LDFLAGS="-L$(INITROOT)/usr/lib -L$(NCURSES_PREFIX)/usr/lib -static -lax25 -lncursesw"
#	cd $(APPS_DIR) && make -j$(nproc)
	cd $(APPS_DIR) && make DESTDIR=$(INITROOT) installconf
ifeq ($(CONFIG_AX25_APPS_CALL),y)
	$(MAKE) -C $(APPS_DIR)/call LDFLAGS="-static"
	mkdir -p $(INITROOT)/usr/bin
	strip $(APPS_DIR)/call/call
	cp $(APPS_DIR)/call/call $(INITROOT)/usr/bin/
endif

ifeq ($(CONFIG_AX25_APPS_MONITOR),y)
	$(MAKE) -C $(APPS_DIR)/ax25mond LDFLAGS="-static"
	mkdir -p $(INITROOT)/usr/sbin/
	strip $(APPS_DIR)/ax25mond/ax25mond
	cp $(APPS_DIR)/ax25mond/ax25mond $(INITROOT)/usr/sbin/
endif
#	cd $(APPS_DIR) && make DESTDIR=$(INITROOT) installconf
#	cd $(APPS_DIR) && make DESTDIR=$(INITROOT) install
endif

ax25-clean:
	@echo ">>> Cleaning AX.25 build artifacts"
	@if [ -d "$(LIB_DIR)" ]; then \
		$(MAKE) -C $(LIB_DIR) clean || true; \
	fi
	@if [ -d "$(TOOLS_DIR)" ]; then \
		$(MAKE) -C $(TOOLS_DIR) clean || true; \
	fi
	@if [ -d "$(APPS_DIR)" ]; then \
		$(MAKE) -C $(APPS_DIR) clean || true; \
	fi