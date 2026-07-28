#!/usr/bin/env bash

import_pin 50-vidstab.sh

# USE_OMP is off because Apple clang ships no OpenMP runtime; enabling it would
# link libomp.dylib out of Homebrew and break the portable binary.
ffbuild_build() {
    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DUSE_OMP=OFF \
        -DSSE2_FOUND=FALSE
    cmake --build build -j "$MJOBS"
    cmake --install build
}

ffbuild_configure() {
    echo --enable-libvidstab
}
