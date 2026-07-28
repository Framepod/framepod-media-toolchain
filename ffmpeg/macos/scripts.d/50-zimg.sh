#!/usr/bin/env bash

import_pin 50-zimg.sh

ffbuild_submodules() { return 0; }

ffbuild_build() {
    ./autogen.sh
    ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libzimg
}
