#!/bin/sh

set -e -u

# Constants

REPO_NAME='dependencies'

# Arguments

DEPS_PATH="${1%/}"
REPO_PATH="${2:-$HOME/work/$REPO_NAME}"

# Functions
die() {
	printf '%s\n' "$2"
	exit $1
}

# Main

mkdir -p "$REPO_PATH"

cp "$DEPS_PATH"/*.pkg.tar* "$REPO_PATH" 2>/dev/null \
	|| die 0 "no dependency packages found, skipping"

cd "$REPO_PATH"
rm -f ./*pkg.tar*.sig

repo-add "$REPO_NAME".db.tar ./*.pkg.*

printf "
[$REPO_NAME]
Server = file://$(pwd)
SigLevel = Optional TrustAll
" | cat - /etc/pacman.conf | sudo dd status=none of=/etc/pacman.conf

sudo pacman -Sy
