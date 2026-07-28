#!/usr/bin/env bash

# Dependency versions live in the win-linux pipeline and are imported here, so a
# bump via win-linux/util/update_scripts.sh reaches both platforms at once.
import_pin() {
    local src="$WINLINUX_SCRIPTS/$1"
    if [[ ! -f $src ]]; then
        echo "import_pin: no such win-linux script: $1" >&2
        return 1
    fi
    eval "$(grep -E '^SCRIPT_(REPO|COMMIT|REV)=' "$src")"
    # A few upstreams (lame) are still SVN, so the pin is a revision, not a hash.
    SCRIPT_PIN="${SCRIPT_COMMIT:-$SCRIPT_REV}"
    [[ -n $SCRIPT_REPO && -n $SCRIPT_PIN ]]
}

# BSD sed needs an explicit empty suffix; patches lifted from win-linux recipes
# would otherwise create stray backup files or fail outright.
sedi() {
    sed -i '' "$@"
}

fetch_source() {
    local name="$1" dir="$SRCDIR/$name"
    rm -rf "$dir"

    if [[ -n $SCRIPT_REV ]]; then
        svn checkout -q "${SCRIPT_REPO}@${SCRIPT_REV}" "$dir"
        return
    fi

    # A shallow fetch has no tags and no history, so `git describe` fails in it.
    # Packages that derive their version that way must opt out of it.
    if [[ -n $SCRIPT_FULL_CLONE ]]; then
        git clone -q "$SCRIPT_REPO" "$dir"
        git -C "$dir" checkout -q "$SCRIPT_PIN"
        return
    fi

    git init -q "$dir"
    git -C "$dir" remote add origin "$SCRIPT_REPO"
    git -C "$dir" fetch -q --depth=1 origin "$SCRIPT_PIN"
    git -C "$dir" checkout -q FETCH_HEAD
}

# Defaults, overridden by whichever scripts.d entry is currently sourced.
ffbuild_enabled()   { return 0; }
ffbuild_submodules() { return 1; }
ffbuild_configure() { return 0; }
ffbuild_cflags()    { return 0; }
ffbuild_ldflags()   { return 0; }
ffbuild_libs()      { return 0; }
