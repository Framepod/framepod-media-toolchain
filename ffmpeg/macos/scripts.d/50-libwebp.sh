#!/usr/bin/env bash

import_pin 50-libwebp.sh

ffbuild_build() {
    # Internal helper library depends on the decoders we disable below.
    sedi '/libanim_util/d' examples/Makefile.am

    ./autogen.sh
    ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --enable-libwebpmux \
        --enable-libwebpdemux \
        --disable-libwebpextras \
        --disable-sdl \
        --disable-gl \
        --disable-png \
        --disable-jpeg \
        --disable-tiff \
        --disable-gif
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libwebp
}
