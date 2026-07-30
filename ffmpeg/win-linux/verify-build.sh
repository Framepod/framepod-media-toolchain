#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ $# -lt 3 ]]; then
    echo "usage: $0 OUTPUT_DIR TARGET VARIANT [ADDIN ...]" >&2
    exit 2
fi

OUTPUT_DIR="$(realpath "$1")"
shift
source util/vars.sh "$@"

[[ -d "$OUTPUT_DIR/bin" ]] || {
    echo "Missing build output: $OUTPUT_DIR/bin" >&2
    exit 1
}

VERIFY_SCRIPT="$(mktemp)"
cleanup() {
    rm -f "$VERIFY_SCRIPT"
}
trap cleanup EXIT

cat >"$VERIFY_SCRIPT" <<'VERIFY'
set -euo pipefail
mkdir -p /tmp/verify
cd /tmp/verify

if [[ $VERIFY_TARGET == win* ]]; then
    export WINEDEBUG=-all
    export WINEPREFIX=/tmp/wine
    ffmpeg() { wine /out/bin/ffmpeg.exe "$@"; }
else
    ffmpeg() { /out/bin/ffmpeg "$@"; }
fi

version="$(ffmpeg -hide_banner -version 2>&1)"
grep -q -- "--enable-cuda-llvm" <<<"$version"
if grep -q -- "--enable-cuda-nvcc" <<<"$version"; then
    echo "FFmpeg itself must remain on the redistributable CUDA LLVM path" >&2
    exit 1
fi

decoders="$(ffmpeg -hide_banner -decoders 2>&1)"
for decoder in libdav1d av1_cuvid h264_cuvid hevc_cuvid; do
    grep -q " $decoder " <<<"$decoders"
done

encoders="$(ffmpeg -hide_banner -encoders 2>&1)"
for encoder in av1_nvenc h264_nvenc hevc_nvenc; do
    grep -q " $encoder " <<<"$encoders"
done

hwaccels="$(ffmpeg -hide_banner -hwaccels 2>&1)"
grep -q "cuda" <<<"$hwaccels"

filters="$(ffmpeg -hide_banner -filters 2>&1)"
grep -q " libvmaf_cuda " <<<"$filters"

ffmpeg -hide_banner -loglevel error \
    -f lavfi -i testsrc2=size=128x72:rate=12 -frames:v 4 \
    -pix_fmt yuv420p -c:v libsvtav1 -preset 13 av1.mkv -y
ffmpeg -hide_banner -loglevel error -hwaccel none -c:v libdav1d \
    -i av1.mkv -frames:v 4 -f null -
VERIFY

docker run --rm \
    -e "VERIFY_TARGET=$TARGET" \
    -v "$OUTPUT_DIR:/out:ro" \
    -v "$VERIFY_SCRIPT:/verify.sh:ro" \
    "$IMAGE" bash /verify.sh
