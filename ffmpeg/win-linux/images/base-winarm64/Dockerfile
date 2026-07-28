ARG GH_REPO=ghcr.io/btbn/ffmpeg-builds
ARG BASE_TAG_SUFFIX=
FROM $GH_REPO/base:latest${BASE_TAG_SUFFIX}

# Upstream clones master, so the toolchain silently follows LLVM main and can
# change between two builds of the same FFmpeg tag. The tag pins LLVM itself too.
ARG LLVM_MINGW_TAG=20260728

RUN \
    git clone --filter=blob:none --branch "$LLVM_MINGW_TAG" https://github.com/mstorsjo/llvm-mingw /llvm-mingw && cd /llvm-mingw && \
    ./build-all.sh --use-linker=bfd --disable-lldb --disable-lldb-mi /opt/llvm-mingw && \
    cd / && \
    rm -rf llvm-mingw

# LLVM/Clang workarounds
RUN \
    ln -s windows.h /opt/llvm-mingw/generic-w64-mingw32/include/Windows.h

# Prepare "cross" environment to heavily favour static builds
RUN \
    find /opt/llvm-mingw \( \
        -name "*.dll" \
        -or -name "*.dll.a" \
        \) -delete && \
    mkdir /opt/ffbuild

ENV FFBUILD_TOOLCHAIN=aarch64-w64-mingw32

ADD toolchain.cmake /toolchain.cmake
ADD cross.meson /cross.meson

ENV PATH="/opt/llvm-mingw/bin:${PATH}" \
    FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --cross-prefix=${FFBUILD_TOOLCHAIN}- --arch=aarch64 --cpu=armv8-a --target-os=mingw32" \
    FFBUILD_CROSS_PREFIX=${FFBUILD_TOOLCHAIN}- \
    FFBUILD_PREFIX=/opt/ffbuild \
    FFBUILD_DESTDIR=/opt/ffdest \
    FFBUILD_DESTPREFIX=/opt/ffdest/opt/ffbuild \
    FFBUILD_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig \
    COMPILER_SYSROOT=/opt/llvm-mingw/aarch64-w64-mingw32 \
    CC="${FFBUILD_TOOLCHAIN}-clang" \
    CXX="${FFBUILD_TOOLCHAIN}-clang++" \
    LD="${FFBUILD_TOOLCHAIN}-ld" \
    AR="${FFBUILD_TOOLCHAIN}-llvm-ar" \
    RANLIB="${FFBUILD_TOOLCHAIN}-llvm-ranlib" \
    NM="${FFBUILD_TOOLCHAIN}-nm" \
    DLLTOOL="${FFBUILD_TOOLCHAIN}-dlltool" \
    GENDEF="gendef" \
    CFLAGS="-I/opt/ffbuild/include -O2 -pipe -march=armv8-a -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CXXFLAGS="-I/opt/ffbuild/include -O2 -pipe -march=armv8-a -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    LDFLAGS="-L/opt/ffbuild/lib -O2 -pipe -march=armv8-a -fstack-protector-strong" \
    STAGE_CFLAGS="" \
    STAGE_CXXFLAGS=""
