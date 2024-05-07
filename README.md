# MilkKernel - Action

**Dynamic Kernel**

**For davinci | Mi 9T / Redmi K20**

**Includes KernelSU**

Please read following **[README](https://github.com/SchweGELBin/kernel_milk_davinci/blob/master/README.md)**

## Custom Kernel
- To build your own custom kernel, fork this repository
- Then edit the ```Changable Data``` section at the beginning of main.sh
- Make sure to use this format: e.g. ```KERNEL_NAME="MilkKernel"```
- Run Action "CI Build"
- You can choose your build options before you start (These will override the variables in main.sh)
- The files will be available at "releases" in your repository

```
# Kernel
KERNEL_NAME       | Name of your Kernel
KERNEL_GIT        | .git link to your Kernel repo
KERNEL_BRANCH     | Branch of your Kernel repo
ANDROID_VERSION   | Your preferred Android version of your kernel

# KernelSU
KERNELSU_REPO     | KernelSU repo (Owner/reponame) default: "tiann/KernelSU"
KSU_ENABLED       | KernelSU enabled ("true") or disabled ("false")

# Anykernel3
ANYKERNEL3_GIT    | .git link to your AnyKernel3 repo
ANYKERNEL3_BRANCH | Branch of your AnyKernel3 repo

# Build
DEVICE_CODE       | Device codename (Mi 9t / RedmiK20 is "davinci")
DEVICE_DEFCONFIG  | Defconfig file of your device (Typically [codename]_defconfig e.g. "davinci_defconfig")
DEVICE_ARCH       | Device architecture (arch/arm, arch/arm64, arch/x64)

# Clang
CLANG_REPO        | Clang (compiler/toolchain) repo (Owner/reponame)
```
