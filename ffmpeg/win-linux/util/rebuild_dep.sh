#!/usr/bin/env bash
# Rebuilds one dependency inside an existing dependency image and commits the result back to
# the same tag. Testing a one-line recipe change otherwise means rebuilding every stage, which
# is an hour or more.
#
# Only the installed files are replaced. FF_CONFIGURE, FF_CFLAGS and FF_LIBS are baked into the
# image by generate.sh, so a change to ffbuild_configure/cflags/libs needs a real makeimage.sh.
#
#   ./util/rebuild_dep.sh vmaf win64 gpl
set -euo pipefail
cd "$(dirname "$0")/.."

RECIPE="$1"
shift
source util/vars.sh "$@"

SCRIPT=""
for candidate in scripts.d/??-"${RECIPE}".sh scripts.d/*/??-"${RECIPE}".sh; do
    [[ -f "$candidate" ]] && { SCRIPT="$candidate"; break; }
done
[[ -n "$SCRIPT" ]] || { echo "no recipe for '${RECIPE}'" >&2; exit 1; }

read -r URL COMMIT <<<"$(source "$SCRIPT"; echo "${SCRIPT_REPO:-} ${SCRIPT_COMMIT:-}")"
[[ -n "${URL:-}" && -n "${COMMIT:-}" ]] || { echo "$SCRIPT is not a git recipe; use makeimage.sh" >&2; exit 1; }

STAGENAME="$(basename "$SCRIPT" .sh)"
CTR="rebuild-${STAGENAME}"

docker image inspect "$IMAGE" >/dev/null
docker tag "$IMAGE" "${IMAGE%:*}:before-rebuild"
docker rm -f "$CTR" &>/dev/null || true

docker run --name "$CTR" -v "$PWD/$SCRIPT:/stage.sh:ro" "$IMAGE" bash -euxc "
    mkdir -p '/$STAGENAME'
    cd '/$STAGENAME'
    git-mini-clone '$URL' '$COMMIT' .
    export STAGENAME='$STAGENAME' SELF='$SCRIPT'
    run_stage /stage.sh
    cp -a \"\$FFBUILD_DESTDIR\"/. /
"

docker commit "$CTR" "$IMAGE" >/dev/null
docker rm "$CTR" >/dev/null
echo "$IMAGE updated; previous image kept as ${IMAGE%:*}:before-rebuild"
