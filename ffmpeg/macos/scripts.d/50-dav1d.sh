#!/usr/bin/env bash

import_pin 50-dav1d.sh

ffbuild_build() {
    meson setup build \
        --prefix="$PREFIX" \
        --buildtype=release \
        --default-library=static
    ninja -C build -j "$MJOBS"
    ninja -C build install
}

ffbuild_configure() {
    echo --enable-libdav1d
}
