#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"

source util/vars.sh
source util/stage.sh

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
GIT_BRANCH="${GIT_BRANCH:-master}"

mkdir -p "$PREFIX" "$SRCDIR" "$DONEDIR" "$ARTIFACTS"

for tool in cmake meson ninja nasm pkg-config autoconf automake glibtoolize svn; do
    command -v "$tool" >/dev/null || MISSING+=" $tool"
done
if [[ -n $MISSING ]]; then
    echo "Missing build tools:$MISSING" >&2
    echo "brew install cmake meson ninja nasm pkg-config autoconf automake libtool svn" >&2
    exit 1
fi

build_stage() {
    local script="$1" name
    name="$(basename "$script" .sh | sed -E 's/^[0-9]+-//')"

    (
        source util/stage.sh
        source "$script"

        ffbuild_enabled || exit 0

        if [[ -f "$DONEDIR/$name" ]] && [[ "$(cat "$DONEDIR/$name")" == "$SCRIPT_PIN" ]]; then
            echo "== $name: up to date"
            exit 0
        fi

        echo "== $name: building $SCRIPT_PIN"
        fetch_source "$name"
        cd "$SRCDIR/$name"
        ffbuild_submodules && git submodule update -q --init --recursive --depth=1
        ffbuild_build
        echo "$SCRIPT_PIN" > "$DONEDIR/$name"
    )
}

for script in scripts.d/*.sh; do
    build_stage "$script"
done

for script in scripts.d/*.sh; do
    (
        source util/stage.sh
        source "$script"
        ffbuild_enabled || exit 0
        echo "CONFIGURE $(ffbuild_configure)"
        echo "CFLAGS $(ffbuild_cflags)"
        echo "LDFLAGS $(ffbuild_ldflags)"
        echo "LIBS $(ffbuild_libs)"
    )
done > "$SRCDIR/.flags"

collect() { grep "^$1 " "$SRCDIR/.flags" | cut -d' ' -f2- | xargs; }
FF_CONFIGURE="$(collect CONFIGURE)"
FF_CFLAGS="$(collect CFLAGS)"
FF_LDFLAGS="$(collect LDFLAGS)"
FF_LIBS="$(collect LIBS)"

echo "== ffmpeg: $GIT_BRANCH"
rm -rf "$SRCDIR/ffmpeg"
git clone -q --filter=blob:none --branch="$GIT_BRANCH" "$FFMPEG_REPO" "$SRCDIR/ffmpeg"
cd "$SRCDIR/ffmpeg"

./configure \
    --prefix="$PREFIX" \
    --pkg-config-flags="--static" \
    --arch="$ARCH" \
    --enable-gpl --enable-version3 --disable-debug \
    --enable-videotoolbox --enable-audiotoolbox --enable-opencl \
    --disable-ffplay \
    --extra-cflags="$CFLAGS $FF_CFLAGS" \
    --extra-cxxflags="$CXXFLAGS" \
    --extra-ldflags="$LDFLAGS $FF_LDFLAGS" \
    --extra-libs="$FF_LIBS" \
    --extra-version="$(date +%Y%m%d)" \
    $FF_CONFIGURE || { cat ffbuild/config.log; exit 1; }

make -j"$MJOBS"
make install

BUILD_NAME="ffmpeg-$(./ffbuild/version.sh .)-macos-arm64-gpl"
PKGROOT="$SRCDIR/pkgroot/$BUILD_NAME"
rm -rf "$SRCDIR/pkgroot"
mkdir -p "$PKGROOT/bin" "$PKGROOT/doc"
cp "$PREFIX"/bin/{ffmpeg,ffprobe} "$PKGROOT/bin"
cp -r "$PREFIX"/share/doc/ffmpeg/. "$PKGROOT/doc" 2>/dev/null || true
cp COPYING.GPLv3 "$PKGROOT/LICENSE.txt"

tar -C "$SRCDIR/pkgroot" -cJf "$ARTIFACTS/$BUILD_NAME.tar.xz" "$BUILD_NAME"
echo "== packaged $ARTIFACTS/$BUILD_NAME.tar.xz"

# A portable binary may reference system frameworks and libSystem only; anything
# under /opt or /usr/local means a Homebrew library leaked into the link.
echo "== linkage"
otool -L "$PKGROOT/bin/ffmpeg" | tail -n +2
if otool -L "$PKGROOT/bin/ffmpeg" | grep -qE '/opt/|/usr/local/'; then
    echo "ERROR: binary links against non-system libraries" >&2
    exit 1
fi
