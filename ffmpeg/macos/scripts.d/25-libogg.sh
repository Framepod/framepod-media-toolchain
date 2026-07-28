#!/usr/bin/env bash

import_pin 25-libogg.sh

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
