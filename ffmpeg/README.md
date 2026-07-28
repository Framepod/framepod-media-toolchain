# FFmpeg builds for framepod

Self-contained FFmpeg binaries, consumed by the Tauri app as a sidecar (desktop) and via
`jniLibs` (Android). Three independent pipelines, one per platform family.

| Directory | Targets | Base |
|---|---|---|
| `win-linux/` | win64, winarm64, linux64, linuxarm64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) @ `8c736b2`, trimmed |
| `macos/` | macos-arm64 | native build, recipes adapted from [markus-perl/ffmpeg-build-script](https://github.com/markus-perl/ffmpeg-build-script) |
| `android/` | arm64-v8a, armeabi-v7a, x86_64 | not started — NDK, `ffmpeg-kit` scripts as reference |

## win-linux

Docker-based cross-compilation. Every dependency is built from source inside the image and
linked statically; the only dynamic dependencies left are the platform's own driver stack
(`libcuda.so.1` / `nvcuda.dll`, VA-API drivers), all loaded via `dlopen` at runtime.

```
./makeimage.sh <target> gpl     # build base + toolchain + dependency image
./build.sh     <target> gpl     # build FFmpeg, emit artifacts/
```

Targets: `win64` `winarm64` `linux64` `linuxarm64`. Variant is always `gpl`.

Optional addins pin an FFmpeg release branch instead of master: `./build.sh linux64 gpl 9.0`.

### macOS host requirements

The driver scripts run on the host and assume GNU userland. Install once:

```
brew install bash coreutils
```

Shebangs are `#!/usr/bin/env bash` so Homebrew's bash 5 wins over the system's 3.2
(`declare -A`, `globstar` and `${VAR,,}` need bash 4+). `util/vars.sh` prepends the coreutils
`gnubin` directory on Darwin for `sha256sum` and `mktemp --suffix`.

### What was removed from upstream

Dropped targets: win32, linux32, linuxppc64, linuxmips64, linuxriscv64. Dropped variants:
all `lgpl`, `nonfree` and `-shared` combinations.

Dependency set was cut from ~70 to 34. Kept: x264, x265, SVT-AV1, dav1d, libvpx, libwebp,
opus, mp3lame, vorbis, soxr, zimg, vmaf, OpenSSL, libxml2, plus the hardware-acceleration
stack (ffnvcodec, AMF, oneVPL, VA-API, Vulkan, OpenCL) and vidstab.

Notable removals: libass and the whole font chain (subtitles are external VTT), libplacebo,
whisper, rubberband, libaom, rav1e, X11 screen capture, and every legacy or regional codec.

`fdk-aac` is deliberately absent — it forces `--enable-nonfree`, which makes the resulting
binaries non-redistributable. FFmpeg's built-in AAC encoder is used instead.

`45-x11/` is kept only because `50-vaapi/50-libva.sh` requires it at build time, and VA-API
in turn is what makes Intel QSV work on Linux. Those libraries are wrapped with `gen-implib`,
so they are not runtime dependencies of the shipped binary.

### Reproducibility

Every dependency in `scripts.d/` is pinned to a commit hash by upstream, but the toolchains
themselves were not: `base-*/Dockerfile` cloned crosstool-ng and llvm-mingw from master, so
the compiler that built a given FFmpeg tag depended on the day the image was made. That is
not academic — an LLVM libc++ change silently broke the winarm64 build. All three are now
pinned via `ARG` (`CT_NG_COMMIT`, `LLVM_MINGW_TAG`, `IMPLIB_COMMIT`), as is meson.

Rust and Node were dropped from the base image entirely. Nothing in the trimmed dependency
set uses them — they were there for rav1e and the libplacebo shader chain — and they were the
two least stable inputs in the tree, a `curl | bash` installer and a nightly toolchain.

The one input still floating is `ubuntu:26.04`, which moves with its own updates. Pinning it
by digest would freeze security fixes too, so it is left alone deliberately.

### Editing the dependency set

`scripts.d/zz-final.sh` lists every package by name in `ffbuild_depends`. Removing a script
from `scripts.d/` requires deleting its name there too, otherwise `generate.sh` fails to
resolve the stage.

Dry-run the graph without Docker:

```
./generate.sh linux64 gpl && grep '^FROM' Dockerfile
```

## macos

Native build on an Apple Silicon host — Docker is not usable here, because the Xcode SDK
cannot legally or practically live in a Linux container. Same layout as `win-linux`
(`scripts.d/NN-name.sh`, `ffbuild_*` functions) but with a plain driver that runs stages
directly instead of emitting a Dockerfile.

```
brew install cmake meson ninja nasm pkg-config autoconf automake libtool svn
./build.sh
```

arm64 only, `MACOSX_DEPLOYMENT_TARGET=11.0` — Big Sur is the first release supporting Apple
Silicon, so it is the floor rather than a compromise. `ARCH` in `util/vars.sh` is the single
place to touch if x86_64 or a universal binary is ever needed.

Fifteen dependencies: x264, x265, SVT-AV1, dav1d, libvpx, libwebp, opus, mp3lame, vorbis,
ogg, soxr, zimg, vmaf, vidstab, OpenSSL. Hardware acceleration comes from VideoToolbox and
AudioToolbox, which are built into FFmpeg and need no external dependency. Vulkan is absent
— macOS has no native driver, only MoltenVK — as are NVENC, AMF, oneVPL and VA-API.

### Dependency versions are not duplicated

`scripts.d/` entries here carry no version of their own. Each calls `import_pin` to read
`SCRIPT_REPO` / `SCRIPT_COMMIT` (or `SCRIPT_REV`, lame is still SVN) out of the matching
win-linux script, so both platforms build the same revisions and a bump via
`win-linux/util/update_scripts.sh` reaches both at once. Only the build invocation differs,
since the native toolchain needs no `--host`, `--cross-file` or `DESTDIR` staging.

Sources are fetched as a shallow single-commit clone. Packages whose build system derives a
version from `git describe` break under that — x265 silently skips installing `x265.pc` —
and set `SCRIPT_FULL_CLONE=1` to opt out.

### Darwin deviations

Three recipes need more than a different configure line, because the upstream build systems
assume a Linux toolchain:

| Package | Why |
|---|---|
| libvorbis | `configure.ac` hardcodes `-force_cpusubtype_ALL`, which ld-prime rejects |
| lame | ships its own `config.rpath`, so autopoint needs `autoreconf -fi` to overwrite it |
| x265 | builds one library per bit depth; the three are merged with cctools `libtool -static` |

### Keeping the binary portable

`PKG_CONFIG_LIBDIR` is pinned to the build prefix so Homebrew's `.pc` files are invisible;
otherwise a `/opt/homebrew` dylib silently ends up linked in. OpenMP is disabled in soxr and
vidstab for the same reason — Apple clang has no OpenMP runtime, so enabling it would pull
`libomp.dylib` from Homebrew. `build.sh` finishes with an `otool -L` check and fails the
build if anything outside the system paths is referenced.

## Open problems

- **vmaf-cuda.** `45-vmaf.sh` builds libvmaf without CUDA, so the `libvmaf_cuda` filter is
  missing. Enabling it needs the CUDA toolkit in the build image. This is straightforward for
  `linux64`; for `win64` it is not, because nvcc on Linux cannot emit COFF host code. Likely
  needs splitting device code out via `nvcc -ptx` and loading it through the driver API.
  Unlike libvmaf, FFmpeg's own CUDA filters need no toolkit at all — `50-ffnvcodec.sh` uses
  `--enable-cuda-llvm`.
- **CI.** No workflows yet. Needs a cron job polling FFmpeg's tags, since GitHub Actions
  cannot trigger on another repository's releases.

## Licensing

Build scripts under `win-linux/` derive from BtbN/FFmpeg-Builds (MIT, see `LICENSE.BtbN`).
Resulting binaries are GPLv3 — `variants/defaults-gpl.sh` sets `--enable-gpl --enable-version3`.
