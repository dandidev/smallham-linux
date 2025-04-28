#!/bin/sh
[ "$IFACE" = "eth0" ] || exit 0

echo "[DOWN] [$IFACE] Deleting default gw for 192.168.0.1"
route del default gw 192.168.0.1
exit 0
