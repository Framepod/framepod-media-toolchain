#!/bin/bash

SCRIPT_REPO="https://git.code.sf.net/p/soxr/code"
SCRIPT_COMMIT="945b592b70470e29f917f4de89b4281fbbd540c0"

ffbuild_enabled() {
    return 0
}

# winarm64's mingw has no OpenMP at all, and the NDK ships libomp as a shared library rather
# than libgomp, which a self-contained build cannot pull in.
soxr_openmp() {
    [[ $TARGET != winarm64 && $TARGET != android ]]
}

# soxr's own .pc declares no private deps, so whatever it needs on top of -lsoxr has to be
# spelled out here or the static link test fails.
soxr_privlibs() {
    local libs=()
    soxr_openmp && libs+=( -lgomp )
    # bionic keeps the math functions in a libm of their own, which clang does not link for us.
    [[ $TARGET == android ]] && libs+=( -lm )
    echo "${libs[@]}"
}

ffbuild_dockerbuild() {
    sed -i 's/VERSION 3.1 /VERSION 3.1...3.10 /g' CMakeLists.txt

    # Short-circuit the check to generate a .pc file. We always want it.
    sed -i 's/NOT WIN32/1/g' src/CMakeLists.txt

    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DWITH_OPENMP="$(soxr_openmp && echo ON || echo OFF)" \
        -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF \
        ..
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"

    privlibs="$(soxr_privlibs)"
    if [[ -n "$privlibs" ]]; then
        echo "Libs.private: $privlibs" >> "$FFBUILD_DESTPREFIX"/lib/pkgconfig/soxr.pc
    fi
}

ffbuild_configure() {
    echo --enable-libsoxr
}

ffbuild_unconfigure() {
    echo --disable-libsoxr
}

ffbuild_ldflags() {
    echo -pthread
}

ffbuild_libs() {
    soxr_privlibs
}
