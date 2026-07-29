ARG GH_REPO=ghcr.io/btbn/ffmpeg-builds
ARG BASE_TAG_SUFFIX=
FROM $GH_REPO/base:latest${BASE_TAG_SUFFIX}

# Google publishes the NDK for linux-x86_64 and darwin only, never linux-aarch64, so this is
# the one image in the tree that has to be amd64. It cross-compiles either way, so the host
# architecture has no bearing on what comes out.
ARG NDK_VERSION=r28b
ARG NDK_SHA512=25f4517febcc6a37a762ec158daf42ff4bd6fd6ea643959395eef109f4f29a8f5256ee997f7c40fee66282686f19cd254c17d2f7ccfa80a4f601bff262997f57

RUN \
    check-wget /tmp/ndk.zip "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" "$NDK_SHA512" && \
    unzip -q /tmp/ndk.zip -d /opt && \
    mv "/opt/android-ndk-${NDK_VERSION}" /opt/ndk && \
    rm /tmp/ndk.zip && \
    # Only arm64-v8a is built, and the other ABIs' sysroots are most of the unpacked size.
    rm -rf /opt/ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/{i686,x86_64,arm}-linux-android* && \
    rm -rf /opt/ndk/simpleperf /opt/ndk/sources/third_party && \
    mkdir /opt/ffbuild

ENV FFBUILD_TOOLCHAIN=aarch64-linux-android

ADD toolchain.cmake /toolchain.cmake
ADD cross.meson /cross.meson

# The API level is part of the compiler name rather than a flag: the NDK keeps one set of
# stub libraries per level, and 24 is what Tauri's Android project targets.
ENV ANDROID_API=24 \
    ANDROID_NDK_ROOT=/opt/ndk \
    PATH="/opt/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"

# Every C++ dependency's .pc asks for -lc++ or -lstdc++, and the NDK sysroot answers with the
# shared runtime, which an app shipping nothing but these binaries cannot load. Shadow both names
# in the prefix the linker reaches first, with the static runtime and its ABI library merged in.
RUN set -e; \
    ndklib="$(dirname "$(find /opt/ndk -name libc++_static.a -path '*aarch64-linux-android*' | head -1)")"; \
    mkdir -p /opt/ffbuild/lib; \
    printf 'CREATE /opt/ffbuild/lib/libc++.a\nADDLIB %s/libc++_static.a\nADDLIB %s/libc++abi.a\nSAVE\nEND\n' \
        "$ndklib" "$ndklib" | llvm-ar -M; \
    ln -s libc++.a /opt/ffbuild/lib/libstdc++.a

ENV FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --arch=aarch64 --target-os=android --enable-cross-compile --enable-mediacodec --enable-jni" \
    FFBUILD_CROSS_PREFIX="llvm-" \
    FFBUILD_PREFIX=/opt/ffbuild \
    FFBUILD_DESTDIR=/opt/ffdest \
    FFBUILD_DESTPREFIX=/opt/ffdest/opt/ffbuild \
    FFBUILD_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig \
    CC="aarch64-linux-android24-clang" \
    CXX="aarch64-linux-android24-clang++" \
    AR="llvm-ar" \
    RANLIB="llvm-ranlib" \
    NM="llvm-nm" \
    STRIP="llvm-strip" \
    CFLAGS="-I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CXXFLAGS="-I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    LDFLAGS="-static-libstdc++ -L/opt/ffbuild/lib -O2 -pipe -fstack-protector-strong -Wl,-z,relro,-z,now" \
    STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition" \
    STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
