#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
[[ $OSTYPE == darwin* ]] && PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
../download.sh hashonly | sha256sum | cut -d" " -f1
