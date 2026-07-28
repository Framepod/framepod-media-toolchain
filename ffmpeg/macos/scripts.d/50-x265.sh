#!/usr/bin/env bash

import_pin 50-x265.sh

# x265 builds one library per bit depth and cannot merge them itself on Darwin,
# so the 10/12-bit variants are built as archives and folded into the main one.
ffbuild_build() {
    local common=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
        -DENABLE_SHARED=OFF
        -DENABLE_CLI=OFF
        -DENABLE_ASSEMBLY=ON
    )

    cmake -S source -B build-12 "${common[@]}" \
        -DHIGH_BIT_DEPTH=ON -DMAIN12=ON -DEXPORT_C_API=OFF
    cmake --build build-12 -j "$MJOBS"

    cmake -S source -B build-10 "${common[@]}" \
        -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF
    cmake --build build-10 -j "$MJOBS"

    cmake -S source -B build-8 "${common[@]}" \
        -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
        -DEXTRA_LINK_FLAGS=-L. \
        -DLINKED_10BIT=ON -DLINKED_12BIT=ON
    cp build-10/libx265.a build-8/libx265_main10.a
    cp build-12/libx265.a build-8/libx265_main12.a
    cmake --build build-8 -j "$MJOBS"

    cd build-8
    mv libx265.a libx265_main.a
    "$GLIBTOOL" -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a
    cmake --install .
}

ffbuild_configure() {
    echo --enable-libx265
}
