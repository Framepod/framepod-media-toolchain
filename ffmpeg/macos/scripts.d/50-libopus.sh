#!/usr/bin/env bash

import_pin 50-libopus.sh

ffbuild_build() {
    ./autogen.sh
    ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --disable-extra-programs \
        --disable-doc
    make -j"$MJOBS"
    make install
}

ffbuild_configure() {
    echo --enable-libopus
}
