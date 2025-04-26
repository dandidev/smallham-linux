mkdir -p ../cloned/linux

git clone --depth 1 --branch master https://github.com/torvalds/linux.git ../cloned/linux
cp ../configs/kernel.config ../cloned/linux/.config

cd ../cloned/linux
make olddefconfig
make -j$(nproc)