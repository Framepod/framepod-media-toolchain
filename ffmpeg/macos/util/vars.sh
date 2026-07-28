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

# Apple's cctools libtool, the only thing on macOS that merges static archives
# (`ar` has no MRI scripts here). Resolved through xcrun so Homebrew's GNU
# libtool cannot win on PATH — the two share a name but no arguments.
LIBTOOL_STATIC="$(xcrun -f libtool)"
