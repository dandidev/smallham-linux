#!/bin/sh

# Paths
ROOT_DIR="initroot"
BIN_DIR="$ROOT_DIR/bin"
DEV_DIR="$ROOT_DIR/dev"
PROC_DIR="$ROOT_DIR/proc"
SYS_DIR="$ROOT_DIR/sys"
INIT_FILE="$ROOT_DIR/init"

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$BIN_DIR" "$DEV_DIR" "$PROC_DIR" "$SYS_DIR"

# Create minimal /dev
echo "Creating /dev entries..."
sudo mknod -m 600 "$DEV_DIR/console" c 5 1
sudo mknod -m 666 "$DEV_DIR/tty" c 5 0

# Create init script
echo "Creating init script..."
cat > "$INIT_FILE" << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
echo "## HAM Linux booted."
exec /bin/sh
while true; do
    echo "Shell exited. Rebooting in 5s..."
    sleep 5
    reboot -f
done
EOF

chmod +x "$INIT_FILE"

# Create initramfs
echo "Creating init.cpio..."
cd "$ROOT_DIR" || exit 1
find . | cpio -H newc -o > ../init.cpio
cd ..

echo "init.cpio created successfully."