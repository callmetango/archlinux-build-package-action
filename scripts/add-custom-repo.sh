#!/bin/sh

set -e -u

# Arguments

REPO_NAME="$1"
REPO_URL="$2"
REPO_SIGLEVEL="$3"


# Main

set +e
DB_URL="${REPO_URL}/${REPO_NAME}.db"
curl --head "$DB_URL" 1>/dev/null 2>&1
if [ $? -ne 0 ] ; then
	echo "package database of custom repo not found, skipping"
	exit 0
fi
set -e

printf "
[$REPO_NAME]
Server = $REPO_URL
SigLevel = $REPO_SIGLEVEL
" | cat - /etc/pacman.conf | sudo dd status=none of=/etc/pacman.conf

n=10
delay=1
while ! sudo pacman --sync --refresh; do
	n=$((n - 1))
	test "$n" -gt 0 || exit 1

	printf '::notice title=Repository synchronization::Retrying in %ds...\n' "$delay"
	sleep "$delay"
	delay=$((delay * 2))
done
