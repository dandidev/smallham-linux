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

# Shell
ln -s busybox sh
ln -s busybox ash

ln -s busybox getty

# Filesystem utilities
ln -s busybox ls
ln -s busybox cat
ln -s busybox cp
ln -s busybox mkdir
ln -s busybox touch

# System and device management
ln -s busybox mount
ln -s busybox umount
ln -s busybox dmesg
ln -s busybox reboot

# Kernel module management
ln -s busybox insmod
ln -s busybox rmmod
ln -s busybox lsmod
ln -s busybox modinfo

# Networking tools (up to 15 useful commands)
ln -s busybox ip
ln -s busybox ifconfig
ln -s busybox ping
ln -s busybox netstat
ln -s busybox hostname
ln -s busybox telnet
ln -s busybox wget
ln -s busybox traceroute
ln -s busybox arp
ln -s busybox nslookup
ln -s busybox udhcpc
ln -s busybox dhcprelay
ln -s busybox route
ln -s busybox ping6
ln -s busybox ipcalc

# Miscellaneous utilities
ln -s busybox echo
ln -s busybox uname
ln -s busybox ps
ln -s busybox kill

# Disk usage information
ln -s busybox df
ln -s busybox du