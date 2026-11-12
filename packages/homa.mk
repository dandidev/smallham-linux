ifndef INCLUDED_HOMA_MK
INCLUDED_HOMA_MK := 1

# Homa transport protocol: out-of-tree kernel module (homa.ko) and its
# test programs. Upstream develops it on Linux 6.17.8 (CONFIG_KERNEL_6_17).

HOMA_REPO := https://github.com/PlatformLab/HomaModule.git
HOMA_COMMIT := 07ce63ef153207a953c42a749ee2429fb5282f55
HOMA_SRC := $(SOURCES)/homa
HOMA_PREFIX := $(BUILD)/homa
HOMA_PREPARED := $(STAMP)/homa.prepared
HOMA_PATCHED := $(STAMP)/homa.patched
# Lets Homa build without IPsec (XFRM), SMP (RPS) and xxhash.
HOMA_PATCH := patches/homa-small-kernel.patch

# C++ programs: musl-gcc has no C++ library, so they are linked statically
# with the host g++ (glibc).
HOMA_UTILS := homa_test server cp_node

#---------------------------------------------------------------------

PKG_FEATURES += HOMA|homa
PKG_DIRS += HOMA|$(HOMA_PREFIX)/lib/modules:/lib/modules

PKG_FEATURES += HOMA_UTILS|homa-utils
PKG_BINS += $(foreach b,$(HOMA_UTILS),HOMA_UTILS|$(HOMA_PREFIX)/usr/bin/$(b))

#---------------------------------------------------------------------

$(HOMA_PREPARED):
	rm -rf $(HOMA_SRC)
	git init -q $(HOMA_SRC)
	cd $(HOMA_SRC) && git fetch -q --depth 1 $(HOMA_REPO) $(HOMA_COMMIT) && \
		git checkout -q FETCH_HEAD
	@touch $@

$(HOMA_PATCHED): $(HOMA_PREPARED) $(HOMA_PATCH)
	cd $(HOMA_SRC) && git clean -fdxq && git reset -q --hard
	cd $(HOMA_SRC) && patch -p1 < $(abspath $(HOMA_PATCH))
	@touch $@

# The module is built against the configured kernel tree; 'modules' writes
# Module.symvers, which the external build needs. Kbuild does not rebuild an
# external module after a kernel config change, so it is cleaned then.
homa: $(HOMA_PATCHED) kernel
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) modules
	if [ $(KERNEL_CONFIGURED) -nt $(HOMA_SRC)/homa.ko ]; then \
	  $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) M=$(HOMA_SRC) clean; \
	fi
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_BUILD) M=$(HOMA_SRC) modules
	@mkdir -p $(HOMA_PREFIX)/lib/modules
	strip --strip-debug -o $(HOMA_PREFIX)/lib/modules/homa.ko $(HOMA_SRC)/homa.ko

homa-utils: $(HOMA_PATCHED)
	$(MAKE) -C $(HOMA_SRC)/util $(HOMA_UTILS) CFLAGS="-Wall -fno-strict-aliasing -Os -I.. -static"
	@mkdir -p $(HOMA_PREFIX)/usr/bin
	cp $(addprefix $(HOMA_SRC)/util/,$(HOMA_UTILS)) $(HOMA_PREFIX)/usr/bin/

homa-clean:
	rm -rf $(HOMA_SRC) $(HOMA_PREFIX) $(HOMA_PREPARED) $(HOMA_PATCHED)

.PHONY: homa homa-utils homa-clean

endif
