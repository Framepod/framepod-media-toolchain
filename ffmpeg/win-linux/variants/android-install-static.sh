#!/bin/bash

package_variant() {
    IN="$1"
    OUT="$2"

    # Tauri v2 has no sidecar on mobile. Android only grants execute permission to files under
    # the app's nativeLibraryDir, and that directory is populated from jniLibs, so the CLI has
    # to travel as a library name. It stays a PIE executable and is run with ProcessBuilder.
    mkdir -p "$OUT"/jniLibs/arm64-v8a
    cp "$IN"/bin/ffmpeg "$OUT"/jniLibs/arm64-v8a/libffmpeg.so
    cp "$IN"/bin/ffprobe "$OUT"/jniLibs/arm64-v8a/libffprobe.so

    mkdir -p "$OUT/doc"
    cp -r "$IN"/share/doc/ffmpeg/* "$OUT"/doc
}
