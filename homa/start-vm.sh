#!/bin/sh
# Start one of the two Homa test VMs: homa/start-vm.sh 1  or  homa/start-vm.sh 2
# The settings are in homa/homa.env. Type 'reboot' in the VM to leave.
set -e

cd "$(dirname "$0")/.."
. homa/homa.env

case "$1" in
    1|2) ;;
    *) echo "Usage: $0 1|2"; exit 1 ;;
esac
eval mac=\$HOMA_VM$1_MAC

for f in "$HOMA_IMAGE-bzImage" "$HOMA_IMAGE-initramfs.cpio.xz" "$HOMA_IMAGE-disk.img"; do
    if [ ! -f "$f" ]; then
        echo "$f is missing. Build the image first: make homa_defconfig && make"
        exit 1
    fi
done

if ! ip link show "$HOMA_BRIDGE" >/dev/null 2>&1; then
    echo "The $HOMA_BRIDGE bridge does not exist."
    echo "Set it up first: \"Bridged network (host setup)\" in README.md"
    exit 1
fi

# Own disk for each VM: two VMs cannot write the same image.
disk=$HOMA_VM_DIR/vm$1-disk.img
mkdir -p "$HOMA_VM_DIR"
if [ ! -f "$disk" ]; then
    echo "Creating $disk from $HOMA_IMAGE-disk.img"
    cp "$HOMA_IMAGE-disk.img" "$disk"
elif [ "$HOMA_IMAGE-disk.img" -nt "$disk" ]; then
    echo "Note: the image was rebuilt. Delete $disk to use the new one (your files on it are lost)."
fi

exec qemu-system-x86_64 -m "$HOMA_MEM" -no-reboot -nographic \
    -kernel "$HOMA_IMAGE-bzImage" -initrd "$HOMA_IMAGE-initramfs.cpio.xz" \
    -append "$HOMA_CMDLINE" \
    -drive file="$disk",format=raw,if=virtio \
    -netdev bridge,id=net0,br="$HOMA_BRIDGE" \
    -device virtio-net-pci,netdev=net0,mac="$mac"
