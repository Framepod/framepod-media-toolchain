#!/usr/bin/env bash

import_pin 25-openssl.sh

# Configure picks darwin64-arm64-cc on its own when building natively.
ffbuild_build() {
    ./Configure \
        --prefix="$PREFIX" \
        --openssldir="$PREFIX" \
        --libdir=lib \
        no-shared \
        no-tests \
        zlib
    make -j"$MJOBS"
    make install_sw
}

ffbuild_configure() {
    echo --enable-openssl
}
