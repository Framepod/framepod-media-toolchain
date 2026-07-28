#!/usr/bin/env bash

import_pin 50-libvpx.sh

ffbuild_build() {
    # libvpx emits GNU ld syntax that Apple's linker rejects.
    sedi 's/,--version-script//g; s/-Wl,--no-undefined -Wl,-soname/-Wl,-undefined,error -Wl,-install_name/g' \
        build/make/Makefile

    ./configure \
        --prefix="$PREFIX" \
        --target=arm64-darwin20-gcc \
        --disable-shared \
        --enable-static \
        --enable-pic \
        --disable-examples \
        --disable-tools \
        --disable-docs \
        --disable-unit-tests \
        --enable-vp9-highbitdepth
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libvpx
}
