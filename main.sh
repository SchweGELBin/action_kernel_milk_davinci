#!/usr/bin/env sh

# Changable Data
# ------------------------------------------------------------

# Kernel
KERNEL_NAME="MilkKernel"
KERNEL_GIT="https://github.com/SchweGELBin/kernel_milk_davinci.git"
KERNEL_BRANCH="vantom-14"
KERNEL_TYPE="vantom"

# KernelSU
KERNELSU_REPO="tiann/KernelSU"
KSU_ENABLED="false"
KSU_TARGET="v0.9.5"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/SchweGELBin/AnyKernel3_davinci.git"
ANYKERNEL3_BRANCH="master"

# Build
DEVICE_CODE="davinci"
DEVICE_ARCH="arch/arm64"

# Clang
CLANG_REPO="ZyCromerZ/Clang"

# ------------------------------------------------------------

# Highlight
msg() {
	echo
	echo -e "\e[1;33m$*\e[0m"
	echo
}

# Input Variables
if [[ $1 == "KSU" ]]; then
    KSU_ENABLED="true"
elif [[ $1 == "NonKSU" ]]; then
    KSU_ENABLED="false"
fi

if [[ $2 == *.git ]]; then
    KERNEL_GIT=$2
fi

if [[ $3 ]]; then
    KERNEL_BRANCH=$3
fi

if [[ $4 ]]; then
    KERNEL_TYPE=$4
fi


if [[ $KERNEL_TYPE == "vantom" ]]; then
    DEVICE_DEFCONFIG="davinci_defconfig"
    COMMON_DEFCONFIG=""
elif [[ $KERNEL_TYPE == "perf" ]]; then
    DEVICE_DEFCONFIG="vendor/davinci.config"
    COMMON_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
else
    DEVICE_DEFCONFIG="davinci_defconfig"
    COMMON_DEFCONFIG=""
fi

msg "Variables"
echo "KSU_ENABLED: $KSU_ENABLED"
echo "KERNEL_GIT: $KERNEL_GIT"
echo "KERNEL_BRANCH: $KERNEL_BRANCH"
echo "DEVICE_DEFCONFIG: $DEVICE_DEFCONFIG"
echo "COMMON_DEFCONFIG: $COMMON_DEFCONFIG"

# Set variables
WORKDIR="$(pwd)"

CLANG_DLINK="$(curl -s https://api.github.com/repos/$CLANG_REPO/releases/latest\
| grep -wo "https.*" | grep Clang-.*.tar.gz | sed 's/.$//')"
CLANG_DIR="$WORKDIR/Clang/bin"

KERNEL_REPO="${KERNEL_GIT::-4}/"
KERNEL_SOURCE="${KERNEL_REPO::-1}/tree/$KERNEL_BRANCH"
KERNEL_DIR="$WORKDIR/$KERNEL_NAME"

KERNELSU_SOURCE="https://github.com/$KERNELSU_REPO"
CLANG_SOURCE="https://github.com/$CLANG_REPO"
README="https://github.com/SchweGELBin/kernel_milk_davinci/blob/master/README.md"

DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/$DEVICE_ARCH/configs/$DEVICE_DEFCONFIG"
IMAGE="$KERNEL_DIR/out/$DEVICE_ARCH/boot/Image.gz"
DTB="$KERNEL_DIR/out/$DEVICE_ARCH/boot/dtb.img"
DTBO="$KERNEL_DIR/out/$DEVICE_ARCH/boot/dtbo.img"

export KBUILD_BUILD_USER=SchweGELBin
export KBUILD_BUILD_HOST=GitHubCI

cd $WORKDIR

# Setup
msg "Setup"

msg "Clang"
mkdir -p Clang
aria2c -s16 -x16 -k1M $CLANG_DLINK -o Clang.tar.gz
tar -C Clang/ -zxvf Clang.tar.gz
rm -rf Clang.tar.gz

CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1 | cut -f1 -d "(" | sed 's/.$//')"
CLANG_VERSION=${CLANG_VERSION::-3} # May get removed later
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1 | cut -f1 -d "(" | sed 's/.$//')"

msg "Kernel"
git clone --depth=1 $KERNEL_GIT -b $KERNEL_BRANCH $KERNEL_DIR

KERNEL_VERSION=$(cat $KERNEL_DIR/Makefile | grep -w "VERSION =" | cut -d '=' -f 2 | cut -b 2-)\
.$(cat $KERNEL_DIR/Makefile | grep -w "PATCHLEVEL =" | cut -d '=' -f 2 | cut -b 2-)\
.$(cat $KERNEL_DIR/Makefile | grep -w "SUBLEVEL =" | cut -d '=' -f 2 | cut -b 2-)\
.$(cat $KERNEL_DIR/Makefile | grep -w "EXTRAVERSION =" | cut -d '=' -f 2 | cut -b 2-)

[ ${KERNEL_VERSION: -1} = "." ] && KERNEL_VERSION=${KERNEL_VERSION::-1}
msg "Kernel Version: $KERNEL_VERSION"

TITLE=$KERNEL_NAME-$KERNEL_VERSION

cd $KERNEL_DIR

msg "KernelSU"
if [[ $KSU_ENABLED == "true" ]]; then
    curl -LSs "https://raw.githubusercontent.com/$KERNELSU_REPO/main/kernel/setup.sh" | bash -s $KSU_TARGET

    echo "CONFIG_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
    echo "CONFIG_HAVE_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
    echo "CONFIG_KPROBE_EVENTS=y" >> $DEVICE_DEFCONFIG_FILE

    KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
    KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10200))
    msg "KernelSU Version: $KERNELSU_VERSION"

    TITLE=$TITLE-$KERNELSU_VERSION
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$KERNELSU_VERSION-$KERNEL_NAME\"/" $DEVICE_DEFCONFIG_FILE
else
    echo "KernelSU Disabled"
    KERNELSU_VERSION="Disabled"
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$KERNEL_NAME\"/" $DEVICE_DEFCONFIG_FILE
fi

# Build
msg "Build"

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

rm -rf out

make O=out $args "$COMMON_DEFCONFIG"
make O=out $args "$DEVICE_DEFCONFIG"

make O=out $args kernelversion
make O=out $args -j"$(nproc --all)"
msg "Kernel version: $KERNEL_VERSION"

# Package
msg "Package"
cd $WORKDIR
git clone --depth=1 $ANYKERNEL3_GIT -b $ANYKERNEL3_BRANCH $WORKDIR/Anykernel3
cd $WORKDIR/Anykernel3
cp $IMAGE .
cp $DTB $WORKDIR/Anykernel3/dtb
cp $DTBO .

# Archive
mkdir -p $WORKDIR/out
if [[ $KSU_ENABLED == "true" ]]; then
  ZIP_NAME="$KERNEL_NAME-KSU.zip"
else
  ZIP_NAME="$KERNEL_NAME-NonKSU.zip"
fi
TIME=$(TZ='Europe/Berlin' date +"%Y-%m-%d %H:%M:%S")
find ./ * -exec touch -m -d "$TIME" {} \;
zip -r9 $ZIP_NAME *
cp *.zip $WORKDIR/out

# Release Files
cd $WORKDIR/out
msg "Release Files"
echo "
## [$KERNEL_NAME]($README)
- **Time**: $TIME # CET

- **Codename**: $DEVICE_CODE
- **Kernel Type**: $KERNEL_TYPE

<br>

- **[Kernel]($KERNEL_SOURCE) Version**: $KERNEL_VERSION
- **[KernelSU]($KERNELSU_SOURCE) Version**: $KERNELSU_VERSION

<br>

- **[CLANG]($CLANG_SOURCE) Version**: $CLANG_VERSION
- **LLD Version**: $LLD_VERSION
" > bodyFile.md
echo "$TITLE" > name.txt
#echo "$KERNEL_NAME" > name.txt

# Finish
msg "Done"
