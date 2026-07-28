#!/usr/bin/env bash

import_pin 50-libmp3lame.sh

ffbuild_build() {
    autoreconf -i

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
