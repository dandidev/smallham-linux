SOURCE_DIR := sources
LIBUDEVZERO_VERSION := 1.0.3
LIBUDEVZERO_TARBALL := libudev-zero-$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_URL := https://github.com/illiliti/libudev-zero/archive/refs/tags/$(LIBUDEVZERO_VERSION).tar.gz
LIBUDEVZERO_SRC := $(SOURCE_DIR)/libudev-zero-$(LIBUDEVZERO_VERSION)
LIBUDEVZERO_PREFIX := $(abspath toolchain/libudev-zero)

.PHONY: libudev-zero-install

libudev-zero-install:
	@echo ">>> Building libudev-zero v$(LIBUDEVZERO_VERSION)"
	@if [ ! -d "$(LIBUDEVZERO_SRC)" ]; then \
		mkdir -p $(SOURCE_DIR); \
		curl -L $(LIBUDEVZERO_URL) -o $(SOURCE_DIR)/$(LIBUDEVZERO_TARBALL); \
		tar xzf $(SOURCE_DIR)/$(LIBUDEVZERO_TARBALL) -C $(SOURCE_DIR); \
	fi

	cd $(LIBUDEVZERO_SRC) && LDFLAGS="-s" make
	cd $(LIBUDEVZERO_SRC) && make PREFIX=$(LIBUDEVZERO_PREFIX)/usr install