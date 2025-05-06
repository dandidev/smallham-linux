LINUX_VERSION := 6.6.30
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
LINUX_SRC := sources/linux-$(LINUX_VERSION)
LINUX_HEADERS_DIR := $(abspath toolchain/linux-headers)
BZIMAGE := $(LINUX_SRC)/arch/x86/boot/bzImage
LINUX_HEADERS_DONE := $(LINUX_HEADERS_DIR)/include/linux/version.h

.PHONY: linux linux-build linux-headers linux-download linux-clean

linux-download:
	@echo ">>> Downloading Linux kernel $(LINUX_VERSION)"
	@mkdir -p sources
	@if [ ! -f sources/$(LINUX_TARBALL) ]; then \
		curl -L $(LINUX_URL) -o sources/$(LINUX_TARBALL); \
	else \
		echo ">>> Kernel tarball already exists."; \
	fi
	@if [ ! -d "$(LINUX_SRC)" ]; then \
		tar -xf sources/$(LINUX_TARBALL) -C sources; \
	else \
		echo ">>> Kernel source already unpacked."; \
	fi

linux-build: linux-download
	@echo ">>> Building Linux kernel"
	cd $(LINUX_SRC) && make defconfig
	cd $(LINUX_SRC) && make -j$$(nproc)

LINUX_HEADERS_DONE := $(LINUX_HEADERS_DIR)/include/linux/version.h

$(LINUX_HEADERS_DONE): linux-download
	@echo ">>> Installing kernel headers"
	cd $(LINUX_SRC) && make headers_install INSTALL_HDR_PATH=$(abspath $(LINUX_HEADERS_DIR))

linux-headers: $(LINUX_HEADERS_DONE)

linux: linux-download linux-build linux-headers

linux-clean:
	@echo ">>> Cleaning Linux kernel"
	@if [ -d "$(LINUX_SRC)" ]; then cd $(LINUX_SRC) && make clean || true; fi
	rm -rf $(LINUX_HEADERS_DIR)
