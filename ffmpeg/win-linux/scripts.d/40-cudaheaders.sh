#!/bin/bash

# libvmaf's CUDA kernels are compiled by clang, not nvcc, and loaded at runtime as PTX through
# the driver API. Nothing links against CUDA, so the only thing missing is what clang needs to
# parse a .cu file: the CUDA headers and libdevice. Those are a few megabytes of the toolkit,
# taken from NVIDIA's pip wheels rather than installing the whole thing.
# 12.8 is the newest release clang 21 claims support for.

CUDA_VER="12.8"
RT_WHL="nvidia_cuda_runtime_cu12-12.8.90-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"
RT_URL="https://files.pythonhosted.org/packages/0d/9b/a997b638fcd068ad6e4d53b8551a7d30fe8b404d6f1804abf1df69838932/${RT_WHL}"
RT_SHA512="f5c695c08e9012032ed4a4a6ea980a3df0faaec6c9b00ef544d46a40137c616095774c02269d444ecdb25b1e035d740fb2b8668968099f04821619c3fac3b977"

NVCC_WHL="nvidia_cuda_nvcc_cu12-12.8.93-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl"
NVCC_URL="https://files.pythonhosted.org/packages/86/0a/962e9c861541b08d62ee38a9e9776a46f75b979c75e7236fa7e09b024470/${NVCC_WHL}"
NVCC_SHA512="f7fa0e20ba78a3665a76b94bfe4d1b0f9c394006bda44425fda45975e724ff800f59040d9520f27101013a452f16bb4053591c6f3e938dc6370275a4f2379053"

ffbuild_enabled() {
    # Only where an NVIDIA GPU is a realistic target. Windows on ARM has no NVIDIA driver.
    [[ $TARGET == linux64 || $TARGET == win64 ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    echo "check-wget \"$RT_WHL\" \"$RT_URL\" \"$RT_SHA512\""
    echo "check-wget \"$NVCC_WHL\" \"$NVCC_URL\" \"$NVCC_SHA512\""
}

ffbuild_dockerbuild() {
    local cuda="$FFBUILD_DESTPREFIX/cuda"

    unzip -q "$RT_WHL" -d rt
    unzip -q "$NVCC_WHL" -d nvcc

    # clang rejects a CUDA directory that has no lib64 and no bin, even when it only needs
    # headers, so both exist and stay empty.
    mkdir -p "$cuda"/nvvm/libdevice "$cuda"/lib64 "$cuda"/bin
    cp -r rt/nvidia/cuda_runtime/include "$cuda"/include
    cp -r nvcc/nvidia/cuda_nvcc/include/* "$cuda"/include/
    cp nvcc/nvidia/cuda_nvcc/nvvm/libdevice/libdevice.10.bc "$cuda"/nvvm/libdevice/

    # clang force-includes this cuRAND header to redeclare blockDim and threadIdx with its own
    # builtin types, but it already declares both in __clang_cuda_builtin_vars.h. libvmaf never
    # calls cuRAND, so an empty file saves pulling a 60 MB wheel for headers nothing reads.
    : > "$cuda"/include/curand_mtgp32_kernel.h
}

ffbuild_configure() {
    return 0
}
