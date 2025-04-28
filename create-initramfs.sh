#!/bin/sh

# Paths
ROOT_DIR="initroot"
BIN_DIR="$ROOT_DIR/bin"
DEV_DIR="$ROOT_DIR/dev"
PROC_DIR="$ROOT_DIR/proc"
SYS_DIR="$ROOT_DIR/sys"
ETC_DIR="$ROOT_DIR/etc"

mkdir -p /proc /sys /dev /var /var/log

echo "Creating init.cpio..."
cd "$ROOT_DIR" || exit 1
find . | cpio -H newc -o > ../init.cpio
cd ..

echo "init.cpio created successfully."