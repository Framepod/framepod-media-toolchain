#!/usr/bin/env bash

import_pin 45-vmaf.sh

ffbuild_build() {
    # Upstream tools do not cross-check and are not shipped.
    : > libvmaf/tools/meson.build

    meson setup build libvmaf \
        --prefix="$PREFIX" \
        --buildtype=release \
        --default-library=static \
        -Dbuilt_in_models=true \
        -Denable_tests=false \
        -Denable_docs=false \
        -Denable_float=true \
        -Denable_asm=true
    ninja -C build -j "$MJOBS"
    ninja -C build install

    # libvmaf is C++ but advertises a C interface; without this ffmpeg's static
    # link misses the standard library symbols.
    echo "Libs.private: -lc++" >> "$PREFIX/lib/pkgconfig/libvmaf.pc"
}

ffbuild_configure() {
    echo --enable-libvmaf
}
