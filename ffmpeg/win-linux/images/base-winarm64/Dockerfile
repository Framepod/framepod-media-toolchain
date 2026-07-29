ARG GH_REPO=ghcr.io/btbn/ffmpeg-builds
ARG BASE_TAG_SUFFIX=
FROM $GH_REPO/base:latest${BASE_TAG_SUFFIX}

# Upstream clones master and runs build-all.sh, which compiles all of LLVM: two hours here,
# five on a 4-vCPU runner, and the toolchain silently follows LLVM main. mstorsjo publishes a
# release tarball built from the same tag with the same ucrt and cfguard defaults, so take
# that. The flags upstream passed (bfd linker, no lldb) only shape the host binaries, not the
# code the toolchain emits. Pinned by hash because a tag alone does not fix the bytes.
ARG LLVM_MINGW_TAG=20260728
ARG LLVM_MINGW_SHA256_arm64=2e6458feb4cc116a4b9afc81ae72e1e1c8b52d9a367aeaf26c12f582dd9674cd
ARG LLVM_MINGW_SHA256_amd64=bdc15cb613f2ef309827a90d409806a45eb68e4e607c290fa1b933d74ab87846
ARG TARGETARCH

RUN \
    case "$TARGETARCH" in \
        arm64) host=aarch64; sha="$LLVM_MINGW_SHA256_arm64" ;; \
        amd64) host=x86_64;  sha="$LLVM_MINGW_SHA256_amd64" ;; \
        *) echo "unsupported build host arch: $TARGETARCH" >&2; exit 1 ;; \
    esac && \
    name="llvm-mingw-${LLVM_MINGW_TAG}-ucrt-ubuntu-22.04-${host}" && \
    curl -fsSL -o /tmp/llvm-mingw.tar.xz \
        "https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_TAG}/${name}.tar.xz" && \
    echo "$sha  /tmp/llvm-mingw.tar.xz" | sha256sum -c - && \
    tar -xf /tmp/llvm-mingw.tar.xz -C /opt && \
    mv "/opt/$name" /opt/llvm-mingw && \
    rm /tmp/llvm-mingw.tar.xz

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
