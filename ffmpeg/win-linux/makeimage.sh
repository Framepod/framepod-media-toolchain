#!/usr/bin/env bash
set -xeo pipefail
cd "$(dirname "$0")"
source util/vars.sh

TMPCFG="$(mktemp --suffix=.toml)"
cat <<EOF >"$TMPCFG"
[worker.oci]
  max-parallelism = 4
EOF
trap "rm -f '$TMPCFG'" EXIT

docker buildx inspect ffbuilder &>/dev/null || docker buildx create \
    --bootstrap \
    --name ffbuilder \
    --config "$TMPCFG" \
    --driver-opt network=host \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=-1

push_image() {
    [[ -z "$PUSH" ]] || docker push "$1"
}

# A runner starts with an empty cache directory and throws it away at the end, so mode=max
# there only costs disk and export time. In CI the registry is the cache that survives.
cache_args() {
    CACHE_ARGS=()
    if [[ -z "$GITHUB_ACTIONS" ]]; then
        CACHE_ARGS=(
            --cache-from=type=local,src=".cache/$1"
            --cache-to=type=local,mode=max,dest=".cache/$1"
        )
    fi
}

# download.sh runs with a placeholder target and would otherwise resolve base to the wrong
# architecture for android.
export BASE_TAG_SUFFIX

# GHCR links a package to its repository through this label. Without it a new package has no
# source to inherit access from, and GITHUB_TOKEN, which is only ever authorised for its own
# repository, is refused the write.
SOURCE_LABEL="org.opencontainers.image.source=https://github.com/${REPO_SLUG}"

if [[ -z "$QUICKBUILD" ]]; then
    # CI splits the toolchain across jobs: one publishes `base`, the four target jobs take it
    # from the registry with SKIP_BASE instead of each rebuilding it.
    BASE_IMAGE_TARGET="${PWD}/.cache/images/base"
    if [[ -z "$SKIP_BASE" && ! -d "${BASE_IMAGE_TARGET}" ]]; then
        cache_args "${BASE_IMAGE/:/_}"
        docker buildx --builder ffbuilder build \
            "${CACHE_ARGS[@]}" \
            --label "$SOURCE_LABEL" \
            --load --tag "${BASE_IMAGE}" \
            "images/base"
        mkdir -p "${BASE_IMAGE_TARGET}"
        docker image save "${BASE_IMAGE}" | tar -x -C "${BASE_IMAGE_TARGET}"
        push_image "${BASE_IMAGE}"
    fi

    if [[ -d "${BASE_IMAGE_TARGET}" ]]; then
        BASE_CONTEXT_SRC="oci-layout://${BASE_IMAGE_TARGET}"
    else
        BASE_CONTEXT_SRC="docker-image://${BASE_IMAGE}"
    fi

    IMAGE_TARGET="${PWD}/.cache/images/base-${TARGET}"
    if [[ ! -d "${IMAGE_TARGET}" ]]; then
        cache_args "${TARGET_IMAGE/:/_}"
        docker buildx --builder ffbuilder build \
            "${CACHE_ARGS[@]}" \
            --build-arg GH_REPO="${REGISTRY}/${REPO}" \
            --build-arg BASE_TAG_SUFFIX="${BASE_TAG_SUFFIX}" \
            --build-context "${BASE_IMAGE}=${BASE_CONTEXT_SRC}" \
            --label "$SOURCE_LABEL" \
            --load --tag "${TARGET_IMAGE}" \
            "images/base-${TARGET}"
        mkdir -p "${IMAGE_TARGET}"
        docker image save "${TARGET_IMAGE}" | tar -x -C "${IMAGE_TARGET}"
        push_image "${TARGET_IMAGE}"
    fi

    CONTEXT_SRC="oci-layout://${IMAGE_TARGET}"
else
    CONTEXT_SRC="docker-image://${TARGET_IMAGE}"
fi

# The toolchain pipeline stops here; the dependency layer belongs to the release pipeline,
# which is versioned by addin and rebuilt far more often.
if [[ -n "$BASE_ONLY" ]]; then
    exit 0
fi

./download.sh
./generate.sh "$TARGET" "$VARIANT" "${ADDINS[@]}"

RECIPE_LABEL="org.framepod.recipe=$(./util/recipe_hash.sh "$TARGET" "$VARIANT" "${ADDINS[@]}")"

cache_args "${IMAGE/:/_}"
docker buildx --builder ffbuilder build \
    "${CACHE_ARGS[@]}" \
    --build-context "${TARGET_IMAGE}=${CONTEXT_SRC}" \
    --label "$SOURCE_LABEL" \
    --label "$RECIPE_LABEL" \
    --load --tag "$IMAGE" .

push_image "$IMAGE"

if [[ -z "$NOCLEAN" ]]; then
    docker buildx rm -f ffbuilder
    rm -rf .cache/images
fi
