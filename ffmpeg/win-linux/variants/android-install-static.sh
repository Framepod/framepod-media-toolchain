#!/bin/bash

package_variant() {
    IN="$1"
    OUT="$2"

    # Tauri has no mobile sidecars, and Android executes only nativeLibraryDir files. Ship the
    # PIE executable through jniLibs under a library name and run it with ProcessBuilder.
    case "$TARGET" in
    android) abi=arm64-v8a ;;
    androidx64) abi=x86_64 ;;
    *) echo "Unknown Android target: $TARGET" >&2; return 1 ;;
    esac

    mkdir -p "$OUT/jniLibs/$abi"
    cp "$IN"/bin/ffmpeg "$OUT/jniLibs/$abi/libffmpeg.so"
    cp "$IN"/bin/ffprobe "$OUT/jniLibs/$abi/libffprobe.so"

    mkdir -p "$OUT/doc"
    cp -r "$IN"/share/doc/ffmpeg/* "$OUT"/doc
}
