#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINLINUX_SCRIPTS="$ROOT/../win-linux/scripts.d"

ARCH=arm64
export MACOSX_DEPLOYMENT_TARGET=11.0

PREFIX="$ROOT/workspace"
SRCDIR="$ROOT/.cache/src"
DONEDIR="$ROOT/.cache/done"
ARTIFACTS="$ROOT/artifacts"

MJOBS="$(sysctl -n hw.ncpu)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export SDKROOT

export CC=clang
export CXX=clang++
export CFLAGS="-arch $ARCH -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -isysroot $SDKROOT -I$PREFIX/include -O2 -fPIC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch $ARCH -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -isysroot $SDKROOT -L$PREFIX/lib"

# LIBDIR, not PATH: pkg-config must not see Homebrew's .pc files, or a dylib
# from /opt/homebrew silently ends up linked into a supposedly portable binary.
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PATH="$PREFIX/bin:$PATH"

# Apple ships its own libtool with incompatible arguments; autotools packages
# that need the GNU one must call this instead.
GLIBTOOL="$(command -v glibtool || true)"
