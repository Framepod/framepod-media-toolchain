#!/bin/bash

SCRIPT_REPO="https://github.com/xiph/opus.git"
SCRIPT_COMMIT="3da9f7a6db1c05c3996cb363a9d1931a978bf1be"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    default_dl .

    # autogen fetches external dependencies, so run it while network access is available.
    echo "./autogen.sh"
}

ffbuild_dockerbuild() {
    # Regenerate with this image's autotools; the download cache may use different versions.
    autoreconf -isf

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --host="$FFBUILD_TOOLCHAIN"
        --disable-shared
        --enable-static
        --disable-extra-programs
    )

    if [[ $TARGET == winarm* ]]; then
        myconf+=(
            --disable-rtcd
        )
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libopus
}

ffbuild_unconfigure() {
    echo --disable-libopus
}
