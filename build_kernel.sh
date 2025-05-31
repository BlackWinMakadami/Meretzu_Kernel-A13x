#!/bin/bash

export ARCH=arm64
export SUBARCH=arm64
export PLATFORM_VERSION=13

export DEFCONFIG=exynos850-a13xx_defconfig
export CLANG_PATH=$PWD/toolchain/zyclang-12/bin

export CROSS_COMPILE=$CLANG_PATH/aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=$CLANG_PATH/arm-linux-androideabi-

export LLVM=1
export LLVM_IAS=1

make $DEFCONFIG
make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) 
