#!/usr/bin/env bash

import_pin 50-x264.sh

ffbuild_build() {
    ./configure \
        --prefix="$PREFIX" \
        --disable-cli \
        --enable-static \
        --enable-pic \
        --disable-lavf \
        --disable-swscale
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libx264
}
