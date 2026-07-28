#!/usr/bin/env bash

import_pin 45-libvorbis.sh

ffbuild_build() {
    # Upstream still hardcodes -force_cpusubtype_ALL for darwin; ld-prime rejects it.
    sedi 's/ -force_cpusubtype_ALL//g' configure.ac
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
