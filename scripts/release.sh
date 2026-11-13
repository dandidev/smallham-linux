#!/bin/sh
# Builds every release variant and packs it into build/release/<version>/:
#
#   smallham-<version>-<variant>-x86_64.tar.xz   QEMU: kernel, initramfs,
#                                                (disk image), run.sh
#   smallham-<version>-<variant>-x86_64.iso      VirtualBox, boots alone
#   smallham-<version>-<variant>-x86_64.zip      VirtualBox: ISO + .vmdk disk
#   smallham-<version>-sources.tar               source code (no kernel)
#   linux-<kernel version>.tar.xz                kernel source (from kernel.org)
#   SHA256SUMS
#
# Usage: make release (from a clean checkout of a release tag). The version
# comes from 'git describe'. Your .config is saved and restored.
set -eu
cd "$(dirname "$0")/.."

VERSION=$(git describe --tags --always --dirty)
OUT=build/out
REL=$(pwd)/build/release/$VERSION
STAGE=$(pwd)/build/release/stage
DL=$(pwd)/build/release/download
REPO_URL=https://github.com/dandidev/smallham-linux

case $VERSION in
v*-*|[!v]*) echo "NOTE: $VERSION is not a release tag, the files are only for testing." ;;
esac

mk() { make -s "print-$1"; }

mkdir -p build/release
SAVED_CONFIG=
if [ -f .config ]; then
    SAVED_CONFIG=build/release/config.saved
    cp .config "$SAVED_CONFIG"
fi
restore_config() { if [ -n "$SAVED_CONFIG" ]; then cp "$SAVED_CONFIG" .config; fi; }
trap restore_config EXIT

rm -rf "$REL" "$STAGE"
mkdir -p "$REL" "$STAGE" "$DL"

# --------------------------------------------------------------------
# License texts of the programs in the images

lic() {  # <dir> <name> <file>...
    d=$1/licenses/$2; shift 2
    mkdir -p "$d"
    cp "$@" "$d/"
}

add_licenses() {  # <dir> <ham: yes|no>
    ksrc=sources/linux-$(mk KERNEL_VERSION)
    lic "$1" smallham LICENSE
    lic "$1" linux "$ksrc/COPYING" "$ksrc/LICENSES/preferred/GPL-2.0" \
        "$ksrc/LICENSES/exceptions/Linux-syscall-note"
    lic "$1" busybox "$(mk BUSYBOX_SRC)/LICENSE"
    lic "$1" musl "$(mk MUSL_SRC)/COPYRIGHT"
    if [ "$2" = yes ]; then
        lic "$1" direwolf "$(mk DIREWOLF_SRC)/LICENSE"
        lic "$1" alsa-lib "$(mk ALSA_LIB_SRC)/COPYING"
        lic "$1" libudev-zero "$(mk LIBUDEVZERO_SRC)/LICENSE"
        lic "$1" ncurses "$(mk NCURSES_SRC)/COPYING"
        lic "$1" libax25 "$(mk LIB_AX25_SRC)/COPYING.LIB"
        lic "$1" ax25-tools "$(mk AX25_TOOLS_SRC)/COPYING"
        lic "$1" ax25-apps "$(mk AX25_APPS_SRC)/COPYING"
    fi
}

readme() {  # <dir> <variant> <text>
    {
        echo "SmallHam Linux $VERSION ($2)"
        echo "$REPO_URL"
        echo
        printf '%s\n' "$3"
        echo
        echo "Licenses: licenses/. Source code: smallham-$VERSION-sources.tar"
        echo "on the release page: $REPO_URL/releases/tag/$VERSION"
    } > "$1/README.txt"
}

# --------------------------------------------------------------------
# Variants: <defconfig> <image name> <qemu|iso|zip>

build_variant() {
    cfg=$1 name=$2 kind=$3
    echo "=== $name ($cfg)"
    make "$cfg" > /dev/null
    if [ "$(mk IMAGE_NAME)" != "$name" ]; then
        echo "ERROR: $cfg builds '$(mk IMAGE_NAME)', expected '$name'" >&2
        exit 1
    fi
    make
    base=$OUT/smallham-$name-x86_64
    pkg=smallham-$VERSION-$name-x86_64
    ham=no
    case $name in ham-*) ham=yes ;; esac
    disk=$(mk CONFIG_ROOTFS_DISK)

    case $kind in
    qemu)
        make run-script
        dir=$STAGE/$pkg
        mkdir -p "$dir"
        cp "$base-bzImage" "$base-initramfs.cpio.xz" "$dir/"
        if [ "$disk" = y ]; then
            cp "$base-disk.img" "$base-rootfs.squashfs" "$dir/"
        fi
        mv "$base-run.sh" "$dir/run.sh"
        add_licenses "$dir" $ham
        if [ "$disk" = y ]; then
            note="The system is on the disk image (disk.img): your changes are kept."
        else
            note="The whole system is in the initramfs (RAM): changes are lost on reboot."
        fi
        readme "$dir" "$name" "Start it in QEMU (qemu-system-x86_64 is needed):
  ./run.sh
Type 'reboot' to leave. Extra QEMU options can be given to run.sh.
$note"
        tar --owner=0 --group=0 --numeric-owner -C "$STAGE" -cJf "$REL/$pkg.tar.xz" "$pkg"
        ;;
    iso)
        make iso
        cp "$base.iso" "$REL/$pkg.iso"
        ;;
    zip)
        make iso
        dir=$STAGE/$pkg
        mkdir -p "$dir"
        cp "$base.iso" "$base-disk.vmdk" "$base-rootfs.squashfs" "$dir/"
        add_licenses "$dir" $ham
        readme "$dir" "$name" "VirtualBox: boot from the .iso and attach the .vmdk (the system
with your changes) to a \"VirtIO SCSI\" storage controller.
Use the \"virtio-net\" network adapter. Step by step: README.md,
\"Run with VirtualBox\"."
        (cd "$STAGE" && zip -qrX "$REL/$pkg.zip" "$pkg")
        ;;
    esac
}

build_variant defconfig               base-initramfs      qemu
build_variant base_squashfs_defconfig base-squashfs       qemu
build_variant ham_defconfig           ham-squashfs        qemu
build_variant base_vbox_defconfig     base-initramfs-vbox iso
build_variant ham_vbox_defconfig      ham-squashfs-vbox   zip

# --------------------------------------------------------------------
# Source code: SmallHam itself and the upstream sources. The kernel (134 MB,
# unmodified) is a separate release file, so the sources archive stays small.

echo "=== sources"
srcname=smallham-$VERSION-sources
src=$STAGE/$srcname
mkdir -p "$src"
git archive --prefix="smallham-$VERSION/" -o "$src/smallham-$VERSION.tar.gz" HEAD

fetch() {  # <url> <file>
    if [ ! -f "$DL/$2" ]; then
        curl -fL "$1" -o "$DL/$2.part"
        mv "$DL/$2.part" "$DL/$2"
    fi
    cp "$DL/$2" "$src/"
}
fetch "$(mk BUSYBOX_URL)" "$(mk BUSYBOX_TARBALL)"
fetch "$(mk MUSL_URL)" "$(mk MUSL_TARBALL)"
fetch "$(mk ALSA_LIB_URL)" "$(mk ALSA_LIB_TARBALL)"
fetch "$(mk LIBUDEVZERO_URL)" "$(mk LIBUDEVZERO_TARBALL)"
fetch "$(mk NCURSES_URL)" "$(mk NCURSES_TARBALL)"

gitpkg() {  # <name> <source dir> <commit> [<pathspec>...]
    name=$1 dir=$2 commit=$3; shift 3
    git -C "$dir" archive --prefix="$name/" "$commit" -- "$@" |
        gzip -9n > "$src/$name-$(echo "$commit" | cut -c1-12).tar.gz"
}
# Without doc/: 20 MB of PDF manuals, not needed to build the program.
gitpkg direwolf "$(mk DIREWOLF_SRC)" "$(mk DIREWOLF_COMMIT)" . ':(exclude)doc'
gitpkg libax25 "$(mk LIB_AX25_SRC)" "$(mk LIB_AX25_COMMIT)"
gitpkg ax25-tools "$(mk AX25_TOOLS_SRC)" "$(mk AX25_TOOLS_COMMIT)"
gitpkg ax25-apps "$(mk AX25_APPS_SRC)" "$(mk AX25_APPS_COMMIT)"

kver=$(mk KERNEL_VERSION)
ktar=$(mk KERNEL_TARBALL)
kurl=$(mk KERNEL_URL)
ksha=$(curl -fsSL "${kurl%/*}/sha256sums.asc" | awk -v f="$ktar" '$2 == f { print $1 }')
if [ -z "$ksha" ]; then
    echo "ERROR: no sha256 for $ktar on kernel.org" >&2
    exit 1
fi
# The kernel source is a separate release file next to the binaries (GPLv2
# section 3: source offered from the same place as the binaries).
if [ ! -f "$DL/$ktar" ]; then
    curl -fL "$kurl" -o "$DL/$ktar.part"
    mv "$DL/$ktar.part" "$DL/$ktar"
fi
if [ "$(sha256sum < "$DL/$ktar" | cut -d' ' -f1)" != "$ksha" ]; then
    echo "ERROR: $ktar does not match the sha256 on kernel.org" >&2
    exit 1
fi
cp "$DL/$ktar" "$REL/"

{
    echo "# Source code of SmallHam Linux $VERSION"
    echo
    echo "| File | SHA256 |"
    echo "|---|---|"
    (cd "$src" && sha256sum -- *.tar.*) | awk '{ print "| " $2 " | " $1 " |" }'
    echo
    echo "The patches for BusyBox, Dire Wolf and ax25-apps are in"
    echo "smallham-$VERSION.tar.gz (patches/), with the Makefile that builds"
    echo "everything. The git sources were fetched from:"
    echo
    echo "- direwolf: $(mk DIREWOLF_REPO) $(mk DIREWOLF_COMMIT)"
    echo "  (without the doc/ folder of PDF manuals; they are in the repository)"
    echo "- libax25: $(mk LIB_AX25_REPO) $(mk LIB_AX25_COMMIT)"
    echo "- ax25-tools: $(mk AX25_TOOLS_REPO) $(mk AX25_TOOLS_COMMIT)"
    echo "- ax25-apps: $(mk AX25_APPS_REPO) $(mk AX25_APPS_COMMIT)"
    echo
    echo "## Linux kernel"
    echo
    echo "The kernel source is a separate file on the release page, because of"
    echo "its size: $ktar. It is the unmodified Linux $kver release"
    echo "(no patches), the same file as on kernel.org:"
    echo
    echo "- $REPO_URL/releases/download/$VERSION/$ktar"
    echo "- $kurl"
    echo "- SHA256: $ksha"
    echo
    echo "The kernel configuration is made by the Makefile from"
    echo "configs/kernel/*.config."
} > "$src/SOURCES.md"

tar --owner=0 --group=0 --numeric-owner -C "$STAGE" -cf "$REL/$srcname.tar" "$srcname"

# --------------------------------------------------------------------

(cd "$REL" && sha256sum -- *.tar.xz *.iso *.zip *.tar > SHA256SUMS)
echo
echo "Release files in $REL:"
ls -l "$REL"
