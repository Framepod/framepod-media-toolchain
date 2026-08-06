#!/usr/bin/env bash

# Drivers run on the host and need GNU coreutils (sha256sum, mktemp --suffix).
[[ $OSTYPE == darwin* ]] && PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

if [[ $# -lt 2 ]]; then
    echo "Invalid Arguments"
    exit -1
fi

TARGET="$1"
VARIANT="$2"
shift 2

if ! [[ -f "variants/${TARGET}-${VARIANT}.sh" ]]; then
    echo "Invalid target/variant"
    exit -1
fi

LICENSE_FILE="COPYING.LGPLv2.1"

# An FFmpeg release line is its own recipe: the name gives both the branch and FFVER. Only
# addins that do more than that need a file, so a new line builds without one being added.
is_release_line() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}

source_addin() {
    if [[ -f "addins/${1}.sh" ]]; then
        source "addins/${1}.sh"
    else
        GIT_BRANCH="release/${1}"
    fi
}

ADDINS=()
ADDINS_STR=""
while [[ "$#" -gt 0 ]]; do
    if ! [[ -f "addins/${1}.sh" ]] && ! is_release_line "$1"; then
        echo "Invalid addin: $1"
        exit -1
    fi

    ADDINS+=( "$1" )
    ADDINS_STR="${ADDINS_STR}${ADDINS_STR:+-}$1"

    shift
done

# Registry paths must be lowercase; the label GHCR matches against must not be, or it links
# the package to nothing.
REPO_SLUG="${GITHUB_REPOSITORY:-Framepod/framepod-media-toolchain}"
REPO="${REPO_SLUG,,}"
REGISTRY="${REGISTRY_OVERRIDE:-ghcr.io}"
# Build images are amd64. The compiler inside each target image decides what architecture
# FFmpeg and dependencies use. A suffix can still select a bootstrap image explicitly.
BASE_TAG_SUFFIX="${BASE_TAG_SUFFIX:-}"
BASE_IMAGE="${REGISTRY}/${REPO}/base:latest${BASE_TAG_SUFFIX}"
TARGET_IMAGE="${REGISTRY}/${REPO}/base-${TARGET}:latest"
IMAGE="${REGISTRY}/${REPO}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}:latest"

# Recipes gate on major*100+minor, computed from the release line rather than a table that
# every new line has to be added to. No line means master, which is newer than all of them.
ffbuild_ffver() {
    if [[ "$ADDINS_STR" =~ ([0-9]+)\.([0-9]+) ]]; then
        echo $(( 10#${BASH_REMATCH[1]} * 100 + 10#${BASH_REMATCH[2]} ))
    else
        echo 99999999
    fi
}


ffbuild_depends() {
    echo base
}

ffbuild_dockerstage() {
    if [[ -n "$SELFCACHE" ]]; then
        to_df "RUN --mount=src=${SELF},dst=/stage.sh --mount=src=${SELFCACHE},dst=/cache.tar.xz run_stage /stage.sh"
    else
        to_df "RUN --mount=src=${SELF},dst=/stage.sh run_stage /stage.sh"
    fi
}

ffbuild_dockerlayer() {
    to_df "COPY --link --from=${SELFLAYER} \$FFBUILD_DESTPREFIX/. \$FFBUILD_PREFIX"
}

ffbuild_dockerfinal() {
    to_df "COPY --link --from=${PREVLAYER} \$FFBUILD_PREFIX/. \$FFBUILD_PREFIX"
}

ffbuild_configure() {
    return 0
}

ffbuild_unconfigure() {
    return 0
}

ffbuild_cflags() {
    return 0
}

ffbuild_uncflags() {
    return 0
}

ffbuild_cxxflags() {
    return 0
}

ffbuild_uncxxflags() {
    return 0
}

ffbuild_ldexeflags() {
    return 0
}

ffbuild_unldexeflags() {
    return 0
}

ffbuild_ldflags() {
    return 0
}

ffbuild_unldflags() {
    return 0
}

ffbuild_libs() {
    return 0
}

ffbuild_unlibs() {
    return 0
}
