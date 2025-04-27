#!/bin/sh

# Paths
ROOT_DIR="initroot"
BIN_DIR="$ROOT_DIR/bin"
DEV_DIR="$ROOT_DIR/dev"
PROC_DIR="$ROOT_DIR/proc"
SYS_DIR="$ROOT_DIR/sys"
ETC_DIR="$ROOT_DIR/etc"

# Create minimal directories
echo "Creating base filesystem directories..."
mkdir -p "$DEV_DIR" "$PROC_DIR" "$SYS_DIR" "$ETC_DIR"

# Create minimal /etc/inittab for busybox init
echo "Creating /etc/inittab..."
cat > "$ETC_DIR/inittab" << 'EOF'
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::respawn:/bin/getty -n -l /bin/sh 115200 tty1
::ctrlaltdel:/bin/reboot -f
EOF

# Build initramfs
echo "Creating init.cpio..."
cd "$ROOT_DIR" || exit 1
find . | cpio -H newc -o > ../init.cpio
cd ..

echo "init.cpio created successfully."