#!/bin/bash

# The normal build needs only headers and libdevice for clang PTX. The nvcc-fatbin addin installs
# NVIDIA's host-native compiler archive as well; it is used only for device code and is never
# linked into FFmpeg.

CUDA_VER="12.8"
RT_WHL="nvidia_cuda_runtime_cu12-12.8.90-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"
RT_URL="https://files.pythonhosted.org/packages/0d/9b/a997b638fcd068ad6e4d53b8551a7d30fe8b404d6f1804abf1df69838932/${RT_WHL}"
RT_SHA512="f5c695c08e9012032ed4a4a6ea980a3df0faaec6c9b00ef544d46a40137c616095774c02269d444ecdb25b1e035d740fb2b8668968099f04821619c3fac3b977"

NVCC_WHL="nvidia_cuda_nvcc_cu12-12.8.93-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl"
NVCC_URL="https://files.pythonhosted.org/packages/86/0a/962e9c861541b08d62ee38a9e9776a46f75b979c75e7236fa7e09b024470/${NVCC_WHL}"
NVCC_SHA512="f7fa0e20ba78a3665a76b94bfe4d1b0f9c394006bda44425fda45975e724ff800f59040d9520f27101013a452f16bb4053591c6f3e938dc6370275a4f2379053"

NVCC_REDIST_VERSION="12.8.93"

ffbuild_nvcc_fatbin_enabled() {
    [[ ${VMAF_CUDA_CODEGEN:-} == nvcc || $ADDINS_STR == *nvcc-fatbin* ]]
}

ffbuild_nvcc_redist() {
    case "$(uname -m)" in
    aarch64 | arm64)
        NVCC_REDIST_ARCH="linux-aarch64"
        NVCC_REDIST="cuda_nvcc-linux-aarch64-${NVCC_REDIST_VERSION}-archive.tar.xz"
        NVCC_REDIST_SHA512="3faa5873c0e94ab923aa127a78b8e637bd02004598c6919533e3080b9cc9e034310c85d2f8cc265c99aa17986af21ae5d5baeb2bf39f57f97bcaf41600b090d9"
        ;;
    x86_64 | amd64)
        NVCC_REDIST_ARCH="linux-x86_64"
        NVCC_REDIST="cuda_nvcc-linux-x86_64-${NVCC_REDIST_VERSION}-archive.tar.xz"
        NVCC_REDIST_SHA512="8fa3f89492f002aee6c1ce4ca760b8348a18e42edd8bfc6153828d671884c8166c4295c2aef9f680053dbae9fbed07fbbae5b1e75d5434725445a039e0aa1746"
        ;;
    *)
        echo "Unsupported nvcc build host: $(uname -m)" >&2
        return 1
        ;;
    esac
    NVCC_REDIST_URL="https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvcc/${NVCC_REDIST_ARCH}/${NVCC_REDIST}"
}

ffbuild_enabled() {
    # Only where an NVIDIA GPU is a realistic target. Windows on ARM has no NVIDIA driver.
    [[ $TARGET == linux64 || $TARGET == win64 ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    echo "check-wget \"$RT_WHL\" \"$RT_URL\" \"$RT_SHA512\""
    if ffbuild_nvcc_fatbin_enabled; then
        ffbuild_nvcc_redist
        echo "check-wget \"$NVCC_REDIST\" \"$NVCC_REDIST_URL\" \"$NVCC_REDIST_SHA512\""
    else
        echo "check-wget \"$NVCC_WHL\" \"$NVCC_URL\" \"$NVCC_SHA512\""
    fi
}

ffbuild_dockerbuild() {
    local cuda="$FFBUILD_DESTPREFIX/cuda"

    unzip -q "$RT_WHL" -d rt
    mkdir -p "$cuda"/include
    cp -r rt/nvidia/cuda_runtime/include/. "$cuda"/include/
    if ffbuild_nvcc_fatbin_enabled; then
        ffbuild_nvcc_redist
        tar xf "$NVCC_REDIST" --strip-components=1 -C "$cuda"
    else
        unzip -q "$NVCC_WHL" -d nvcc
        mkdir -p "$cuda"/nvvm/libdevice "$cuda"/lib64 "$cuda"/bin
        cp -r nvcc/nvidia/cuda_nvcc/include/* "$cuda"/include/
        cp nvcc/nvidia/cuda_nvcc/nvvm/libdevice/libdevice.10.bc "$cuda"/nvvm/libdevice/
    fi

    # clang force-includes this cuRAND header to redeclare blockDim and threadIdx with its own
    # builtin types, but it already declares both in __clang_cuda_builtin_vars.h. libvmaf never
    # calls cuRAND, so an empty file saves pulling a 60 MB wheel for headers nothing reads.
    : > "$cuda"/include/curand_mtgp32_kernel.h
}

ffbuild_configure() {
    return 0
}
