#!/usr/bin/env sh

WORKDIR="$(pwd)"

# Clang
CLANG_DLINK="$(curl -s https://api.github.com/repos/ZyCromerZ/Clang/releases/latest | grep -wo "https.*" | grep Clang-.*.tar.gz)"
CLANG_DIR="$WORKDIR/Clang/bin"

# Kernel
KERNEL_NAME="MilkKernel"
KERNEL_GIT="https://github.com/SchweGELBin/kernel_milk_davinci.git"
KERNEL_BRANCHE="13"
KERNEL_DIR="$WORKDIR/$KERNEL_NAME"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/SchweGELBin/AnyKernel3_davinci.git"
ANYKERNEL3_BRANCHE="master"

# Build
DEVICES_CODE="davinci"
DEVICE_DEFCONFIG="davinci_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"
IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dtb.img"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"

export KBUILD_BUILD_USER=SchweGELBin
export KBUILD_BUILD_HOST=GitHubCI

# Sperated (Bold + Yellow)
msg() {
	echo
	echo -e "\e[1;33m$*\e[0m"
	echo
}

cd $WORKDIR

# Clang
msg "Work on $WORKDIR"
msg "Cloning Clang"
mkdir -p Clang
aria2c -s16 -x16 -k1M $CLANG_DLINK -o Clang.tar.gz
tar -C Clang/ -zxvf Clang.tar.gz
rm -rf Clang.tar.gz

# Toolchain Versions
CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1)"

msg "Cloning Kernel"
git clone --depth=1 $KERNEL_GIT -b $KERNEL_BRANCHE $KERNEL_DIR
cd $KERNEL_DIR

msg "Patching KernelSU"
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
            echo "CONFIG_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
            echo "CONFIG_HAVE_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
            echo "CONFIG_KPROBE_EVENTS=y" >> $DEVICE_DEFCONFIG_FILE
KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10200))
msg "KernelSU version: $KERNELSU_VERSION"

# PATCH KERNELSU
msg "Applying patches"

apply_patchs () {
for patch_file in $WORKDIR/patchs/*.patch
	do
	patch -p1 < "$patch_file"
done
}
apply_patchs

sed -i "/CONFIG_LOCALVERSION=\"-$KERNELSU_VERSION-$KERNEL_NAME\"/" $DEVICE_DEFCONFIG_FILE

# BUILD KERNEL
msg "Compilation"

args="PATH=$CLANG_DIR:$PATH \
ARCH=arm64 \
SUBARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
CC=clang \
NM=llvm-nm \
CXX=clang++ \
AR=llvm-ar \
LD=ld.lld \
STRIP=llvm-strip \
OBJDUMP=llvm-objdump \
OBJSIZE=llvm-size \
READELF=llvm-readelf \
HOSTAR=llvm-ar \
HOSTLD=ld.lld \
HOSTCC=clang \
HOSTCXX=clang++ \
LLVM=1 \
LLVM_IAS=1"

# Linux Kernel Version
rm -rf out
make O=out $args $DEVICE_DEFCONFIG
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.14")
msg "Linux Kernel version: $KERNEL_VERSION"
make O=out $args -j"$(nproc --all)"

msg "Packing Kernel"
cd $WORKDIR
git clone --depth=1 $ANYKERNEL3_GIT -b $ANYKERNEL3_BRANCHE $WORKDIR/Anykernel3
cd $WORKDIR/Anykernel3
cp $IMAGE .
cp $DTB $WORKDIR/Anykernel3/dtb
cp $DTBO .

# PACK FILE
TIME=$(TZ='Europe/Berlin' date +"%Y-%m-%d %H:%M:%S")
ZIP_NAME="$KERNEL_NAME.zip"
find ./ * -exec touch -m -d "$TIME" {} \;
zip -r9 $ZIP_NAME *
mkdir -p $WORKDIR/out && cp *.zip $WORKDIR/out

cd $WORKDIR/out
echo "
### $KERNEL_NAME
1. **Time**: $TIME # CET
2. **Device Code**: $DEVICES_CODE
3. **LINUX Version**: $KERNEL_VERSION
4. **KERNELSU Version**: $KERNELSU_VERSION
5. **CLANG Version**: $CLANG_VERSION
6. **LLD Version**: $LLD_VERSION
" > RELEASE.md
echo "$KERNEL_NAME-$KERNEL_VERSION-$KERNELSU_VERSION" > RELEASETITLE.txt
cat RELEASE.md
cat RELEASETITLE.txt

# Finish
msg "Done"
