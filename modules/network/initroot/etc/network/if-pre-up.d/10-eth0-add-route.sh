#!/bin/sh
[ "$IFACE" = "eth0" ] || exit 0

echo "[PRE-UP] [$IFACE] Adding default gw 192.168.0.1"
route add default gw 192.168.0.1
exit 0
