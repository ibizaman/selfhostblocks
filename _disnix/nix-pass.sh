#!/usr/bin/env bash

# nix-pass.sh

set -euo pipefail

f=$(mktemp)
trap "rm $f" EXIT
pass show "$1" | head -c -1 > $f
nix-instantiate --eval -E "builtins.readFile $f"
