#!/bin/sh

set -e -u

# Arguments
# $1: PGP public keys file

# Constants

TMPDIR="$(mktemp -d)"

# Main

printf '%s\n' "$1" > "$TMPDIR"/keys.asc
sudo pacman-key --add "$TMPDIR"/keys.asc

cat "$TMPDIR"/keys.asc \
	| gpg --import-options show-only --with-colon --import \
	| grep '^fpr:' | cut -d ':' -f 10 > "$TMPDIR"/key-ids.csv

while IFS= read -r KEY_ID ; do
	sudo pacman-key --lsign-key "$KEY_ID"
done < "$TMPDIR"/key-ids.csv
