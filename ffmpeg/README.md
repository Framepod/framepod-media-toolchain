# FFmpeg builds for framepod

Self-contained FFmpeg binaries, consumed by the Tauri app as a sidecar (desktop) and via
`jniLibs` (Android). Three independent pipelines, one per platform family.

| Directory | Targets | Base |
|---|---|---|
| `win-linux/` | win64, winarm64, linux64, linuxarm64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) @ `8c736b2`, trimmed |
| `macos/` | macos-arm64 | not started — plan: fork of [markus-perl/ffmpeg-build-script](https://github.com/markus-perl/ffmpeg-build-script) |
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

### Editing the dependency set

`scripts.d/zz-final.sh` lists every package by name in `ffbuild_depends`. Removing a script
from `scripts.d/` requires deleting its name there too, otherwise `generate.sh` fails to
resolve the stage.

Dry-run the graph without Docker:

```
./generate.sh linux64 gpl && grep '^FROM' Dockerfile
```

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
