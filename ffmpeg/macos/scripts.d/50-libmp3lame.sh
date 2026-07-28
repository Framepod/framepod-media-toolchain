#!/usr/bin/env bash

import_pin 50-libmp3lame.sh

ffbuild_build() {
    # lame commits its own config.rpath; without -f autopoint refuses to overwrite it.
    autoreconf -fi

    export CFLAGS="$CFLAGS -DNDEBUG -Wno-error=incompatible-pointer-types"

    ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --enable-nasm \
        --disable-gtktest \
        --disable-cpml \
        --disable-frontend \
        --disable-decoder
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libmp3lame
}
