#!/bin/bash

# The normal build needs only headers and libdevice for clang PTX. The nvcc-fatbin addin installs
# NVIDIA's host-native compiler archive as well; it is used only for device code and is never
# linked into FFmpeg.

RT_WHL="nvidia_cuda_runtime_cu12-12.8.90-py3-none-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"
RT_URL="https://files.pythonhosted.org/packages/0d/9b/a997b638fcd068ad6e4d53b8551a7d30fe8b404d6f1804abf1df69838932/${RT_WHL}"
RT_SHA512="f5c695c08e9012032ed4a4a6ea980a3df0faaec6c9b00ef544d46a40137c616095774c02269d444ecdb25b1e035d740fb2b8668968099f04821619c3fac3b977"

NVCC_WHL="nvidia_cuda_nvcc_cu12-12.8.93-py3-none-manylinux2010_x86_64.manylinux_2_12_x86_64.whl"
NVCC_URL="https://files.pythonhosted.org/packages/86/0a/962e9c861541b08d62ee38a9e9776a46f75b979c75e7236fa7e09b024470/${NVCC_WHL}"
NVCC_SHA512="f7fa0e20ba78a3665a76b94bfe4d1b0f9c394006bda44425fda45975e724ff800f59040d9520f27101013a452f16bb4053591c6f3e938dc6370275a4f2379053"

NVCC_REDIST_VERSION="13.3.73"
NVCC_CUDART_VERSION="13.3.29"

ffbuild_nvcc_fatbin_enabled() {
    [[ ${VMAF_CUDA_CODEGEN:-} == nvcc || $ADDINS_STR == *nvcc-fatbin* ]]
}

ffbuild_nvcc_redists() {
    case "$(uname -m)" in
    aarch64 | arm64)
        NVCC_REDIST_ARCH="linux-sbsa"
        NVCC_REDIST_SHA512="f23890cdbb412516fb0b5965b46e96f0fb2ff267daa2822dabbf138e9c72753bbc6e57b4e96ea1d29d6d6f1228cb196e02287b7738f3b32d86f53dae53d4a4de"
        NVCC_CRT_SHA512="822a6f444f22a0518b9f601e6111e65d2ec508f0d6b0d4cff12557ef391929807707fb1750c1af6b53256895921d3b95abba553946a3e0b25c3c4e2886ba8969"
        NVCC_CUDART_SHA512="884ba67147afcc492a88883c4250430e8299345982105fab851058fa25de89bc0c80742efe65e9df69ee39ab94e3cd4266c4e9a4486522b470a25300946498ec"
        NVCC_NVVM_SHA512="f4814d2fde67d5a235f936580cd6f4d962afd4c88785b3496b1f4491a2f70a8262d4049fc4472fe46901be03a5686212c4e9ade5fa1de9b4a1a22aec3ba14b18"
        ;;
    x86_64 | amd64)
        NVCC_REDIST_ARCH="linux-x86_64"
        NVCC_REDIST_SHA512="87512a57a3115b41d34ccb451c2ce86d2c2545f4c8eaac2d12219a84e874d01a265c630b4e63d3d38956199fda460a43083a3f2c65ddcfc5617f4f6279417e80"
        NVCC_CRT_SHA512="794a1cb232d679636c9556e45e7add8dea3788abe5f4e511e9338650e64e5b81796295cba13b015ce2ef026bbda6d3236da890a8fa851a6414663dbed4214858"
        NVCC_CUDART_SHA512="4b52d76bdd5863e3934adcb2edba7cb32853f906df5c14eb9c147fc2fdc6746fd310ebb153b039db464da6d3b97e14154c1151a6f66b28d86679edba46c4f05b"
        NVCC_NVVM_SHA512="4f5cc2527de639a0328604dc37691a926508fe00af45c93d5b7960c2ad75edb5edd310977faff9caa0b1c9cdbcb85c8cec632c73b2027c33fddb73017eef80db"
        ;;
    *)
        echo "Unsupported nvcc build host: $(uname -m)" >&2
        return 1
        ;;
    esac
    NVCC_REDIST="cuda_nvcc-${NVCC_REDIST_ARCH}-${NVCC_REDIST_VERSION}-archive.tar.xz"
    NVCC_CRT="cuda_crt-${NVCC_REDIST_ARCH}-${NVCC_REDIST_VERSION}-archive.tar.xz"
    NVCC_CUDART="cuda_cudart-${NVCC_REDIST_ARCH}-${NVCC_CUDART_VERSION}-archive.tar.xz"
    NVCC_NVVM="libnvvm-${NVCC_REDIST_ARCH}-${NVCC_REDIST_VERSION}-archive.tar.xz"
    NVCC_REDIST_BASE="https://developer.download.nvidia.com/compute/cuda/redist"
}

ffbuild_enabled() {
    # Only where an NVIDIA GPU is a realistic target. Windows on ARM has no NVIDIA driver.
    [[ $TARGET == linux64 || $TARGET == win64 ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    if ffbuild_nvcc_fatbin_enabled; then
        ffbuild_nvcc_redists
        echo "check-wget \"$NVCC_REDIST\" \"$NVCC_REDIST_BASE/cuda_nvcc/$NVCC_REDIST_ARCH/$NVCC_REDIST\" \"$NVCC_REDIST_SHA512\""
        echo "check-wget \"$NVCC_CRT\" \"$NVCC_REDIST_BASE/cuda_crt/$NVCC_REDIST_ARCH/$NVCC_CRT\" \"$NVCC_CRT_SHA512\""
        echo "check-wget \"$NVCC_CUDART\" \"$NVCC_REDIST_BASE/cuda_cudart/$NVCC_REDIST_ARCH/$NVCC_CUDART\" \"$NVCC_CUDART_SHA512\""
        echo "check-wget \"$NVCC_NVVM\" \"$NVCC_REDIST_BASE/libnvvm/$NVCC_REDIST_ARCH/$NVCC_NVVM\" \"$NVCC_NVVM_SHA512\""
    else
        echo "check-wget \"$RT_WHL\" \"$RT_URL\" \"$RT_SHA512\""
        echo "check-wget \"$NVCC_WHL\" \"$NVCC_URL\" \"$NVCC_SHA512\""
    fi
}

ffbuild_dockerbuild() {
    local cuda="$FFBUILD_DESTPREFIX/cuda"

    mkdir -p "$cuda"/include
    if ffbuild_nvcc_fatbin_enabled; then
        ffbuild_nvcc_redists
        for archive in "$NVCC_REDIST" "$NVCC_CRT" "$NVCC_CUDART" "$NVCC_NVVM"; do
            tar xf "$archive" --strip-components=1 -C "$cuda"
        done
    else
        unzip -q "$RT_WHL" -d rt
        cp -r rt/nvidia/cuda_runtime/include/. "$cuda"/include/
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
