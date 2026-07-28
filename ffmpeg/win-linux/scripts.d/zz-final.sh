#!/bin/bash

SCRIPT_SKIP="1"

ffbuild_depends() {
    echo libiconv
    echo zlib
    echo gmp
    echo libxml2
    echo openssl
    echo xz
    echo libvorbis
    echo opencl
    echo vmaf
    echo x11
    echo vulkan
    echo amf
    echo dav1d
    echo ffnvcodec
    echo libmp3lame
    echo libopus
    echo libvpx
    echo libwebp
    echo onevpl
    echo schannel
    echo soxr
    echo svtav1
    echo vaapi
    echo vidstab
    echo x264
    echo x265
    echo zimg

    echo rpath
}

ffbuild_enabled() {
    return 0
}

ffbuild_dockerfinal() {
    return 0
}

ffbuild_dockerdl() {
    return 0
}

ffbuild_dockerlayer() {
    return 0
}

ffbuild_dockerstage() {
    return 0
}

ffbuild_dockerbuild() {
    return 0
}

ffbuild_ldexeflags() {
    return 0
}
