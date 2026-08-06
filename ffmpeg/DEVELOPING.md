# Working on the builds locally

`README.md` describes what the pipelines produce. This is how to run them without paying CI
prices for every experiment.

## Host setup

Docker (OrbStack works) plus GNU userland for the driver scripts:

```
brew install bash coreutils
```

Budget ~40 GB of disk. The base images alone are 2.5–5.5 GB each.

## Full local build

```
cd ffmpeg/win-linux
./makeimage.sh win64 gpl 8.1     # base -> base-win64 -> win64-gpl-8.1
./build.sh     win64 gpl 8.1     # FFmpeg itself
```

Roughly: base toolchain hours (crosstool-ng), dependency image ~1 h, FFmpeg 15–30 min.

`makeimage.sh` reads `SKIP_BASE` (take `base` from the registry), `BASE_ONLY` (stop before the
dependency layer), `QUICKBUILD` (take `base-<target>` from the registry instead of building and
re-exporting it), `PUSH` and `NOCLEAN`.

`build.sh` reads `GIT_BRANCH_OVERRIDE` / `GIT_COMMIT` to pick the FFmpeg source and
`FFBUILD_OUTPUT_DIR` for where the artifacts land:

```
GIT_BRANCH_OVERRIDE=release/8.1 FFBUILD_OUTPUT_DIR=/tmp/out ./build.sh win64 gpl
```

`makeimage.sh` saves base images into `.cache/images` and feeds them to the next layer from
there. A stale copy silently outlives an edit to `images/*/Dockerfile`, so delete the directory
after touching one.

## Iterating without a full rebuild

### Dependency graph — seconds, no Docker

```
./generate.sh linux64 gpl 8.1 && grep '^FROM' Dockerfile
```

Catches a broken recipe and an unresolvable stage. This is what CI's
`preflight` job runs for all six targets.

### One dependency — minutes

```
./util/rebuild_dep.sh vmaf win64 gpl
```

Rebuilds that one recipe inside the existing dependency image and commits the result back to
the same tag, keeping the old image as `:before-rebuild`. Turns a one-line recipe change from
an hour into a couple of minutes.

It replaces installed files only. `FF_CONFIGURE`, `FF_CFLAGS` and `FF_LIBS` are baked into the
image as `ENV` by `generate.sh`, so a change to `ffbuild_configure`, `ffbuild_cflags` or
`ffbuild_libs` still needs `makeimage.sh`.

### FFmpeg configure only — a minute

FFmpeg's configure stops at the *first* missing library, so a broken dependency surfaces one
failure per run. Running just configure against an already-built image is far cheaper than
`build.sh`, which always goes on to `make`:

```
img=ghcr.io/framepod/framepod-media-toolchain/win64-gpl:latest
docker run --rm "$img" bash -c '
    git clone --depth 1 --filter=blob:none -b release/8.1 \
        https://github.com/FFmpeg/FFmpeg.git /ffmpeg && cd /ffmpeg
    ./configure --prefix=/prefix --pkg-config-flags=--static \
        $FFBUILD_TARGET_FLAGS $FF_CONFIGURE \
        --extra-cflags="$FF_CFLAGS" --extra-cxxflags="$FF_CXXFLAGS" \
        --extra-libs="$FF_LIBS" --extra-ldflags="$FF_LDFLAGS" \
        --extra-ldexeflags="$FF_LDEXEFLAGS" \
        --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --nm="$NM" \
        ${STRIP:+--strip=$STRIP} || tail -40 ffbuild/config.log'
```

Same flags `build.sh` passes. Fixes can be applied inside the container and retried in place.

## Checking what actually shipped

A macOS host has no `readelf`, so run the binutils inside any dependency image:

```
img=ghcr.io/framepod/framepod-media-toolchain/win64-gpl:latest
docker run --rm -v "$PWD/out:/out" "$img" bash -c '
    x86_64-w64-mingw32-objdump -p /out/bin/ffmpeg.exe | grep "DLL Name"
    llvm-readelf -d /out/lib/libffmpeg.so | grep NEEDED'
```

Nothing outside the platform's own driver stack may appear there.

The rest works on the host:

```
# how it was configured
strings -a ffmpeg.exe | grep -m1 -o -- '--enable-gpl.*'

# libvmaf's CUDA kernels are embedded as PTX text, so their quality is greppable.
# -O0 device code spills parameters to local memory; an optimised build has far fewer.
grep -c -a -o __local_depot ffmpeg.exe
```

## Apple Silicon: amd64 build images

All `win-linux` build images run as `linux/amd64`; this keeps CI uniform and supports tools such
as the Android NDK and NVCC which are unavailable as Linux arm64 hosts. On Apple Silicon Docker
emulates them. Under Rosetta, GNU tar's syscalls may be mistranslated and every `tar` inside a
container can fail with `Function not implemented`: `run_stage` unpacking a source archive,
`autopoint` unpacking gettext's m4 files, and so on.

The workaround belongs in a scratch script, never in the repo: CI runs amd64 natively and has
no such problem, and adding `libarchive-tools` to the shared `base` image would force a rebuild
of all six toolchain images to fix a defect only this machine has.

```
sed -i '' -e 's|tar xaf /cache.tar.xz|bsdtar xf /cache.tar.xz|' util/run_stage.sh
cat >> images/base/Dockerfile <<'EOF'
RUN apt-get update -qq && apt-get install -y -qq libarchive-tools && rm -rf /var/lib/apt/lists/* \
    && mv /bin/tar /bin/tar.gnu && ln -s /usr/bin/bsdtar /bin/tar
EOF
```

Restore the tree from copies afterwards, not with `git checkout --`, or it takes real
uncommitted work with it. No stage runs `apt-get`, so nothing downstream needs GNU tar back.

## What makes CI rebuild an image

`release.yml` reuses the dependency image from ghcr only when both match: the image's
architecture equals the runner's, and its `org.framepod.recipe` label equals
`util/recipe_hash.sh` for that target. The hash covers `generate.sh`, `util/run_stage.sh`, every
recipe in `scripts.d/` including subdirectories, the variant, the addins and the base image's
manifest digest.

Practical consequence: editing any recipe rebuilds the dependency image for **all six**
targets, not only the one that recipe affects.

## Dispatching CI

`toolchain.yml` (manual) publishes `base` and the six `base-<target>` images. Only worth
running when a pin in `images/*/Dockerfile` moves — it takes hours.

`release.yml` (daily cron, or manual with a line like `8.1`) builds dependency images where
needed, then FFmpeg for all six platforms, then publishes the release.

Order matters when both are needed: `release` pulls `base-<target>:latest` from the registry, so
a base image fix has to land first.
