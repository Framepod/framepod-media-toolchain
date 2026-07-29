#!/usr/bin/env bash
# Fingerprints everything that decides what ends up in a dependency image: the recipes, the
# generator that arranges them, and the base image they are stacked on. The published tag carries
# no version of its own, so without this a changed recipe is silently served from an old build.
set -euo pipefail
cd "$(dirname "$0")/.."
source util/vars.sh "$@"

{
    cat generate.sh util/run_stage.sh scripts.d/*.sh "variants/${TARGET}-${VARIANT}.sh"
    for addin in "${ADDINS[@]}"; do cat "addins/${addin}.sh"; done
    # Manifest only, so this stays a metadata request rather than a pull.
    docker buildx imagetools inspect --format '{{.Manifest.Digest}}' "$TARGET_IMAGE" 2>/dev/null \
        || echo "no-base"
} | sha256sum | cut -c1-16
