#!/bin/bash

SCRIPT_REPO="https://github.com/Netflix/vmaf.git"
SCRIPT_COMMIT="0f9912e4714cb0918f474361fc2c7ef2f0a791b5"

ffbuild_enabled() {
    return 0
}

ffbuild_depends() {
    echo cudaheaders
    # The CUDA path reaches the driver through nv-codec-headers rather than linking libcuda.
    echo ffnvcodec
}

ffbuild_dockerbuild() {
    # Kill build of unused and broken tools
    echo > libvmaf/tools/meson.build

    # The bundled libsvm defines ::swap, which ADL now drags into libc++'s
    # __split_buffer and makes every call there ambiguous. Only bites the
    # llvm-mingw targets; libstdc++ resolves swap qualified.
    sed -i -E 's/\bswap\(/libsvm_swap(/g' libvmaf/src/svm.cpp

    # 40-cudaheaders.sh only lands this where an NVIDIA GPU is a realistic target, so its
    # presence is what decides whether libvmaf_cuda gets built.
    local cuda="$FFBUILD_PREFIX/cuda"
    if [[ -d $cuda ]]; then
        install -m755 /dev/stdin /usr/local/bin/bin2c <<'BIN2C'
#!/usr/bin/env python3
# Stands in for NVIDIA's bin2c, the only toolkit binary the clang path would need, for a job
# that is a hex dump: turn each compiled PTX into the C array libvmaf links in.
import sys

name, padd, const, path = "data", None, False, None
argv = sys.argv[1:]
i = 0
while i < len(argv):
    if argv[i] == "--name":
        i += 1
        name = argv[i]
    elif argv[i] == "--padd":
        i += 1
        padd = int(argv[i], 0)
    elif argv[i] == "--const":
        const = True
    elif not argv[i].startswith("--"):
        path = argv[i]
    i += 1

with open(path, "rb") as f:
    data = f.read()
if padd is not None:
    data += bytes([padd])

print("%sunsigned char %s[] = {" % ("const " if const else "", name))
for off in range(0, len(data), 16):
    print("".join("0x%02x," % b for b in data[off:off + 16]))
print("};")
BIN2C

        # The .cu targets are custom_targets, so meson passes them neither the project's include
        # dirs, which upstream expects a toolkit on the default search path to supply, nor
        # anything from --buildtype. nvcc defaults device code to -O3; clang defaults to -O0 and
        # leaves the kernels spilling their parameters into local memory.
        sed -i "s|'--cuda-gpu-arch=sm_75',|'--cuda-path=$cuda', '-I', '$FFBUILD_PREFIX/include', '-O3', '--cuda-gpu-arch=sm_75',|" \
            libvmaf/src/meson.build
        grep -q -- "-O3" libvmaf/src/meson.build || return -1
    fi

    # Those custom targets use include paths relative to a build dir inside libvmaf.
    cd libvmaf && mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        -Dbuilt_in_models=true
        -Denable_tests=false
        -Denable_docs=false
        -Denable_float=true
    )

    if [[ $TARGET == *32 ]]; then
        myconf+=(
            -Denable_avx512=false
            -Denable_asm=false
        )
    else
        myconf+=(
            -Denable_avx512=true
            -Denable_asm=true
        )
    fi

    if [[ $TARGET == win* || $TARGET == linux* || $TARGET == android* ]]; then
        myconf+=(
            --cross-file=/cross.meson
        )
    else
        echo "Unknown target"
        return -1
    fi

    if [[ -d $cuda ]]; then
        myconf+=( -Denable_cuda=true -Denable_nvcc=false )
    fi

    # Meson emits the buildtype's -O3 before the image's CFLAGS, so its -O2 wins. Restating it
    # here is additive; -Dc_args would replace the image's flags rather than extend them.
    CFLAGS="$CFLAGS -O3" CXXFLAGS="$CXXFLAGS -O3" meson "${myconf[@]}" .. || cat meson-logs/meson-log.txt
    ninja -j"$(nproc)"
    DESTDIR="$FFBUILD_DESTDIR" ninja install

    sed -i 's/Libs.private:/Libs.private: -lstdc++/; t; $ a Libs.private: -lstdc++' "$FFBUILD_DESTPREFIX"/lib/pkgconfig/libvmaf.pc
}

ffbuild_configure() {
    (( $(ffbuild_ffver) >= 501 )) || return 0
    echo --enable-libvmaf
}

ffbuild_unconfigure() {
    echo --disable-libvmaf
}
