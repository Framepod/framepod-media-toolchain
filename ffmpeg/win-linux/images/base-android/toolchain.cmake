# The NDK ships its own toolchain file, which knows about ABI names, STL selection and the
# per-API sysroot layout. Reproducing that here would only get it subtly wrong, so include it
# and pass the choices it expects.
set(FFBUILD_ANDROID_API 24)

set(ANDROID_ABI arm64-v8a)
set(ANDROID_PLATFORM android-${FFBUILD_ANDROID_API})
set(ANDROID_STL c++_static)

include(/opt/ndk/build/cmake/android.toolchain.cmake)

# The NDK points CMAKE_<LANG>_COMPILER at a bare clang and carries the target triple separately
# in CMAKE_<LANG>_COMPILER_TARGET, which CMake injects into its own compile rules only. x265
# assembles its NEON sources through add_custom_command, which bypasses those rules, so a bare
# clang there builds for the host. The per-API driver wrappers carry the triple themselves.
set(CMAKE_C_COMPILER   aarch64-linux-android${FFBUILD_ANDROID_API}-clang)
set(CMAKE_CXX_COMPILER aarch64-linux-android${FFBUILD_ANDROID_API}-clang++)

list(APPEND CMAKE_FIND_ROOT_PATH /opt/ffbuild)
