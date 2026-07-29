# FFmpeg builds for framepod

Self-contained FFmpeg binaries, consumed by the Tauri app as a sidecar (desktop) and via
`jniLibs` (Android). Three independent pipelines, one per platform family.

| Directory | Targets | Base |
|---|---|---|
| `win-linux/` | win64, winarm64, linux64, linuxarm64 | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) @ `8c736b2`, trimmed |
| `macos/` | macos-arm64 | native build, recipes adapted from [markus-perl/ffmpeg-build-script](https://github.com/markus-perl/ffmpeg-build-script) |
| — | android arm64-v8a | built by `win-linux/` as a fifth target, NDK toolchain |

See [DEVELOPING.md](DEVELOPING.md) for running and debugging the builds locally.

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

Pinning llvm-mingw to a release tag also removed the reason to compile it. Upstream runs
`build-all.sh`, which builds all of LLVM — 99 minutes here, an estimated five hours on a
4-vCPU runner, against a 6-hour job limit — but that is only unavoidable while tracking
master, since no prebuilt exists for an arbitrary commit. A tag has one: `base-winarm64`
now downloads mstorsjo's release tarball, verified by sha256 and selected by `TARGETARCH`,
which takes 20 seconds. The two were compared before the swap — same LLVM commit, same
mingw-w64 15.0, bit-identical target headers, and the tarball is a strict superset of files
(it keeps lldb, which upstream's `--disable-lldb` dropped). The flags upstream passed
(`--use-linker=bfd`, `--disable-lldb`) shape only the host binaries, not emitted code; the
release build's `--thinlto --pgo` is why the image shrank from 5.76 GB to 3.27 GB.

crosstool-ng has no equivalent — it publishes no binaries, so `base-win64`, `base-linux64`
and `base-linuxarm64` still build their toolchain, about 26 minutes each.

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

### android

A fifth target of the same pipeline rather than its own tree: the NDK runs under Linux, so
the Docker scheme applies unchanged and the recipes are shared. Only `arm64-v8a`, at API 24,
which is what Tauri's Android project targets and also the floor for 64-bit ARM.

The dependency set is the macOS one — no VA-API, AMF, NVENC, oneVPL, Vulkan, OpenCL or X11.
Hardware acceleration is MediaCodec, and since FFmpeg 8 that reaches the codecs through the
NDK's C API (`mediacodec_deps="android mediandk pthreads"`) rather than JNI, so it needs no
JavaVM in the process and survives being run as a separate process.

Tauri v2 has no sidecar on mobile. Android grants execute permission only to files under the
app's `nativeLibraryDir`, which is populated from `jniLibs`, so the CLI ships as
`jniLibs/arm64-v8a/libffmpeg.so` — still a PIE executable, run with `ProcessBuilder`, despite
the name.

This is the one image that must be x86_64: Google publishes the NDK for `linux` and `darwin`,
never `linux-aarch64`. Its CI job therefore runs on `ubuntu-latest` while the other four use
arm64 runners, and `base` exists in two architectures, the amd64 one tagged `latest-amd64`.

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

## vmaf-cuda

`libvmaf_cuda` is built for `linux64` and `win64`, the two targets where an NVIDIA GPU is a
realistic prospect. It costs no runtime dependency: libvmaf's kernels are compiled to PTX,
embedded in the binary, and loaded through the driver API that `nv-codec-headers` reaches by
`dlopen`, exactly as NVENC already does. A build without a GPU present is unaffected.

The usual objection to this is that libvmaf needs nvcc, and nvcc on Linux cannot emit COFF
host code, which would rule out `win64`. That only applies to the default path.
`-Denable_nvcc=false` makes libvmaf compile the kernels with clang instead, device-only, so
no host code is involved and the host platform stops mattering.

What clang does still need is CUDA headers and `libdevice`, which `40-cudaheaders.sh` takes
from NVIDIA's pip wheels — 5.5 MB in the image rather than a toolkit. Three details are not
obvious: clang refuses a CUDA directory with no `lib64` and no `bin`, so both exist and stay
empty; it force-includes a cuRAND header to redeclare `blockDim` and `threadIdx`, which its
own builtins already declare, so an empty file stands in for a 60 MB wheel; and NVIDIA's
`bin2c` is replaced by a short script, being the one toolkit binary the clang path would
otherwise need for what amounts to a hex dump.

`45-vmaf.sh` patches three things upstream assumes. `custom_target` gets none of the project's
include directories. The `.cu` include paths are relative to a build directory inside
`libvmaf/`, which is why the build happens there rather than at the repository root. And a
`custom_target` gets nothing from `--buildtype` either, so the kernels compiled at clang's `-O0`
default — nvcc defaults device code to `-O3`, which is why the nvcc path never showed it. That
shipped once: the PTX carried 110 local-memory depots and CUDA VMAF ran an order of magnitude
slower than the CPU implementation. `-O3` is now passed explicitly and a `grep` guard fails the
stage if the patch ever stops applying.

Kernels are compiled for `sm_75`, so Turing and newer. The driver JIT-compiles the PTX for
the actual device; older cards get no `libvmaf_cuda`.

FFmpeg's own CUDA filters are unrelated to this and need no headers beyond `nv-codec-headers`
— `50-ffnvcodec.sh` passes `--enable-cuda-llvm`.

## CI

Two pipelines, split by how often their output changes. Both run on `ubuntu-24.04-arm`,
because the images are arm64 — the cross-compilers inside them do not care what host they
run on, and macOS builds on `macos-15`.

`toolchain.yml` is manual (`workflow_dispatch`). It builds `base` and the four
`base-<target>` images and pushes them to ghcr, which takes hours and is only warranted when
a pin in `images/*/Dockerfile` moves. `makeimage.sh` gained `BASE_ONLY`, `SKIP_BASE` and
`PUSH` for it: one job publishes `base`, the rest pull it instead of rebuilding it four times.

`release.yml` polls FFmpeg's tags on a daily cron, since Actions cannot trigger on another
repository's releases, and also takes a tag by hand. It builds the dependency image for the
minor line if ghcr has none yet, then FFmpeg itself for all five targets, and publishes a
release. Patch releases on a line reuse the image and cost only the FFmpeg build.

The version reaches both steps as one addin, which is what keeps them consistent: `FFVER`
is derived from `ADDINS_STR` and decides which dependencies go into the image and which
`FF_CONFIGURE` flags are baked in, so an image built for one line cannot be used to build
another. A line with no `addins/<line>.sh` fails the run rather than falling back to master.

## Licensing

Build scripts under `win-linux/` derive from BtbN/FFmpeg-Builds (MIT, see `LICENSE.BtbN`).
Resulting binaries are GPLv3 — `variants/defaults-gpl.sh` sets `--enable-gpl --enable-version3`.
