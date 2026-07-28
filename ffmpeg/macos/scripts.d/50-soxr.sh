#!/usr/bin/env bash

import_pin 50-soxr.sh

ffbuild_build() {
    sedi 's/VERSION 3.1 /VERSION 3.1...3.10 /g' CMakeLists.txt
    # Upstream only emits a .pc file off-Windows via this guard; we always want it.
    sedi 's/NOT WIN32/1/g' src/CMakeLists.txt

    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DWITH_OPENMP=OFF
    cmake --build build -j "$MJOBS"
    cmake --install build
}

ffbuild_configure() {
    echo --enable-libsoxr
}
