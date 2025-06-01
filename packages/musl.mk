ifndef INCLUDED_MUSL_MK
INCLUDED_MUSL_MK := 1

MUSL_VERSION := 1.2.4
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_SRC := $(SOURCES)/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(PREFIX)/musl
MUSL_PREPARED := $(STAMP)/musl.prepared
MUSL_INSTALLED := $(STAMP)/musl.installed

MUSL_CFLAGS := "-Os -I$(LINUX_HEADERS_DIR)/include"

#---------------------------------------------------------------------

$(MUSL_PREPARED):
	curl -L $(MUSL_URL) -o $(SOURCES)/$(MUSL_TARBALL);
	tar -xzf $(SOURCES)/$(MUSL_TARBALL) -C $(SOURCES);
	@touch $@

$(MUSL_INSTALLED): $(MUSL_PREPARED) | kernel-headers
	cd $(MUSL_SRC) && make distclean || true
	cd $(MUSL_SRC) && CFLAGS=$(MUSL_CFLAGS) ./configure --prefix=$(MUSL_PREFIX) --syslibdir=$(MUSL_PREFIX)/lib
	cd $(MUSL_SRC) && make
	cd $(MUSL_SRC) && make install
	@touch $@

musl: $(MUSL_INSTALLED)

musl-clean:
	rm -rf $(MUSL_SRC) $(SOURCES)/$(MUSL_TARBALL) $(MUSL_PREFIX) $(MUSL_PREPARED) $(MUSL_INSTALLED)

export MUSL_PREFIX := $(MUSL_PREFIX)
export MUSL_CC := $(MUSL_PREFIX)/bin/musl-gcc

endif