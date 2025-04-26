mkdir -p ../cloned/busybox

git clone --depth 1 --branch master https://git.busybox.net/busybox ../cloned/busybox
cp ../configs/busybox.config ../cloned/busybox/.config

cd ../cloned/busybox
make olddefconfig
make -j$(nproc)