#!/bin/sh

BUSYBOX_SOURCE="cloned/busybox/busybox"
BIN_DIR="initroot/bin"

# Copy busybox binary
echo "Copying busybox binary..."
cp "$BUSYBOX_SOURCE" "$BIN_DIR/" || {
  echo "Error: busybox binary not found at $BUSYBOX_SOURCE"
  exit 1
}

cd "$BIN_DIR" || {
  echo "Error: could not enter $BIN_DIR"
  exit 1
}

# Extract commands
COMMANDS="$(./busybox --list)"
for cmd in $COMMANDS; do
    ln -sf busybox "$cmd"
done

# Busybox Init
cd ..
ln -s bin/busybox init