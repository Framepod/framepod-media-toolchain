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

if [[ -z "$QUICKBUILD" ]]; then
    # CI splits the toolchain across jobs: one publishes `base`, the four target jobs take it
    # from the registry with SKIP_BASE instead of each rebuilding it.
    BASE_IMAGE_TARGET="${PWD}/.cache/images/base"
    if [[ -z "$SKIP_BASE" && ! -d "${BASE_IMAGE_TARGET}" ]]; then
        docker buildx --builder ffbuilder build \
            --cache-from=type=local,src=.cache/"${BASE_IMAGE/:/_}" \
            --cache-to=type=local,mode=max,dest=.cache/"${BASE_IMAGE/:/_}" \
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
        docker buildx --builder ffbuilder build \
            --cache-from=type=local,src=.cache/"${TARGET_IMAGE/:/_}" \
            --cache-to=type=local,mode=max,dest=.cache/"${TARGET_IMAGE/:/_}" \
            --build-arg GH_REPO="${REGISTRY}/${REPO}" \
            --build-context "${BASE_IMAGE}=${BASE_CONTEXT_SRC}" \
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

docker buildx --builder ffbuilder build \
    --cache-from=type=local,src=.cache/"${IMAGE/:/_}" \
    --cache-to=type=local,mode=max,dest=.cache/"${IMAGE/:/_}" \
    --build-context "${TARGET_IMAGE}=${CONTEXT_SRC}" \
    --load --tag "$IMAGE" .

push_image "$IMAGE"

if [[ -z "$NOCLEAN" ]]; then
    docker buildx rm -f ffbuilder
    rm -rf .cache/images
fi
