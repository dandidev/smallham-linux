ifndef INCLUDED_LIBUDEVZERO_MK
INCLUDED_LIBUDEVZERO_MK := 1

LIBUDEVZERO_VERSION := 1.0.3
LIBUDEVZERO_TARBALL := libudev-zero-$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_URL := https://github.com/illiliti/libudev-zero/archive/refs/tags/$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_SRC := $(SOURCES)/libudev-zero-$(LIBUDEVZERO_VERSION)
LIBUDEVZERO_PREFIX := $(PREFIX)/libudev-zero

LIBUDEVZERO_LDFLAGS := "-s"

#---------------------------------------------------------------------

$(LIBUDEVZERO_SRC)/.prepared:
	curl -L $(LIBUDEVZERO_URL) -o $(SOURCES)/$(LIBUDEVZERO_TARBALL);
	tar xzf $(SOURCES)/$(LIBUDEVZERO_TARBALL) -C $(SOURCES);
	@touch $@

libudev-zero: $(LIBUDEVZERO_SRC)/.prepared
	cd $(LIBUDEVZERO_SRC) && LDFLAGS=$(LIBUDEVZERO_LDFLAGS) make
	cd $(LIBUDEVZERO_SRC) && make PREFIX=$(LIBUDEVZERO_PREFIX)/usr install

endif