ARG GH_REPO=ghcr.io/btbn/ffmpeg-builds
ARG BASE_TAG_SUFFIX=
FROM $GH_REPO/base:latest${BASE_TAG_SUFFIX}

ARG ANDROID_ABI=arm64-v8a
ARG ANDROID_TRIPLE=aarch64-linux-android
ARG FFMPEG_ARCH=aarch64
ARG MESON_CPU_FAMILY=aarch64

# Google publishes the NDK for linux-x86_64 and darwin only, never linux-aarch64. The shared
# build host is amd64; these parameters independently select the Android output ABI.
ARG NDK_VERSION=r28b
ARG NDK_SHA512=25f4517febcc6a37a762ec158daf42ff4bd6fd6ea643959395eef109f4f29a8f5256ee997f7c40fee66282686f19cd254c17d2f7ccfa80a4f601bff262997f57

RUN \
    check-wget /tmp/ndk.zip "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" "$NDK_SHA512" && \
    unzip -q /tmp/ndk.zip -d /opt && \
    mv "/opt/android-ndk-${NDK_VERSION}" /opt/ndk && \
    rm /tmp/ndk.zip && \
    # Keep only the selected ABI; the other sysroots are most of the unpacked size.
    find /opt/ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib -mindepth 1 -maxdepth 1 \
        -type d ! -name "${ANDROID_TRIPLE}*" -exec rm -rf {} + && \
    rm -rf /opt/ndk/simpleperf /opt/ndk/sources/third_party && \
    mkdir /opt/ffbuild

ENV FFBUILD_TOOLCHAIN=${ANDROID_TRIPLE}

ADD toolchain.cmake /toolchain.cmake.in
ADD cross.meson /cross.meson.in
RUN sed \
        -e "s|@ANDROID_ABI@|${ANDROID_ABI}|g" \
        -e "s|@ANDROID_TRIPLE@|${ANDROID_TRIPLE}|g" \
        -e "s|@MESON_CPU_FAMILY@|${MESON_CPU_FAMILY}|g" \
        /cross.meson.in > /cross.meson && \
    sed \
        -e "s|@ANDROID_ABI@|${ANDROID_ABI}|g" \
        -e "s|@ANDROID_TRIPLE@|${ANDROID_TRIPLE}|g" \
        /toolchain.cmake.in > /toolchain.cmake && \
    rm /cross.meson.in /toolchain.cmake.in

# The API level is part of the compiler name rather than a flag: the NDK keeps one set of
# stub libraries per level, and 24 is what Tauri's Android project targets.
ENV ANDROID_API=24 \
    ANDROID_NDK_ROOT=/opt/ndk \
    PATH="/opt/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"

# Every C++ dependency's .pc asks for -lc++ or -lstdc++, and the NDK sysroot answers with the
# shared runtime, which an app shipping nothing but these binaries cannot load. Shadow both names
# in the prefix the linker reaches first, with the static runtime and its ABI library merged in.
RUN set -e; \
    ndklib="$(dirname "$(find /opt/ndk -name libc++_static.a -path "*${ANDROID_TRIPLE}*" | head -1)")"; \
    mkdir -p /opt/ffbuild/lib; \
    printf 'CREATE /opt/ffbuild/lib/libc++.a\nADDLIB %s/libc++_static.a\nADDLIB %s/libc++abi.a\nSAVE\nEND\n' \
        "$ndklib" "$ndklib" | llvm-ar -M; \
    ln -s libc++.a /opt/ffbuild/lib/libstdc++.a

ENV FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --arch=${FFMPEG_ARCH} --target-os=android --enable-cross-compile --enable-mediacodec --enable-jni" \
    FFBUILD_CROSS_PREFIX="llvm-" \
    FFBUILD_PREFIX=/opt/ffbuild \
    FFBUILD_DESTDIR=/opt/ffdest \
    FFBUILD_DESTPREFIX=/opt/ffdest/opt/ffbuild \
    FFBUILD_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig \
    CC="${ANDROID_TRIPLE}24-clang" \
    CXX="${ANDROID_TRIPLE}24-clang++" \
    AR="llvm-ar" \
    RANLIB="llvm-ranlib" \
    NM="llvm-nm" \
    STRIP="llvm-strip" \
    CFLAGS="-I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CXXFLAGS="-I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    LDFLAGS="-static-libstdc++ -L/opt/ffbuild/lib -O2 -pipe -fstack-protector-strong -Wl,-z,relro,-z,now" \
    STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition" \
    STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
