include linux.mk

MUSL_VERSION := 1.2.4
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
MUSL_SRC := $(SOURCE_DIR)/musl-$(MUSL_VERSION)
MUSL_PREFIX := $(abspath toolchain/musl)

KERNEL_SRC := $(SOURCE_DIR)/linux
KERNEL_HEADERS := $(TOOLCHAIN_DIR)/linux-headers

TOOLCHAIN_DIR := $(abspath toolchain)

.PHONY: musl-install

musl-install: linux
	@echo ">>> Building musl toolchain $(MUSL_VERSION)"
	@if [ ! -d "$(SOURCE_DIR)" ]; then mkdir -p $(SOURCE_DIR); fi
	@if [ ! -f "$(SOURCE_DIR)/$(MUSL_TARBALL)" ]; then \
		curl -L $(MUSL_URL) -o $(SOURCE_DIR)/$(MUSL_TARBALL); \
	fi
	@if [ ! -d "$(MUSL_SRC)" ]; then \
		tar -xzf $(SOURCE_DIR)/$(MUSL_TARBALL) -C $(SOURCE_DIR); \
	fi

	cd $(MUSL_SRC) && make distclean || true
	cd $(MUSL_SRC) && ./configure --prefix=$(MUSL_PREFIX)
	cd $(MUSL_SRC) && make -j$$(nproc)
	cd $(MUSL_SRC) && make install

export MUSL_PREFIX := $(MUSL_PREFIX)
export MUSL_CC := $(MUSL_PREFIX)/bin/musl-gcc