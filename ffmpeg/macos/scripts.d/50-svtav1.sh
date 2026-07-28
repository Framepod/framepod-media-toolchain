#!/usr/bin/env bash

import_pin 50-svtav1.sh

ffbuild_build() {
    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DBUILD_APPS=OFF \
        -DSVT_AV1_LTO=OFF
    cmake --build build -j "$MJOBS"
    cmake --install build
}

ffbuild_configure() {
    echo --enable-libsvtav1
}
