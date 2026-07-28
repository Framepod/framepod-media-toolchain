#!/usr/bin/env bash

import_pin 45-libvorbis.sh

ffbuild_build() {
    ./autogen.sh
    ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --disable-oggtest
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libvorbis
}
