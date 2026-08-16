#!/bin/bash

set -e -u


# Constants

CARCH=$(uname -m) # TODO make configurable

SCRIPTS_PATH="$HOME"/bin

SRCDIR="${GITHUB_WORKSPACE}/${INPUT_PATH}"
SRCDIR="${SRCDIR%/}"

REPODIR="$INPUT_REPO_ADD_PATH"
test "$REPODIR" || REPODIR="$INPUT_PATH"
REPODIR="${GITHUB_WORKSPACE}/${REPODIR}"
REPODIR="${REPODIR%/}"


# Set up environment

# shellcheck source=./scripts/gh-helpers.sh
. "$SCRIPTS_PATH"/gh-helpers.sh

. ~/.makepkg.conf

test "$INPUT_PKGDEST" && \
	export PKGDEST="${GITHUB_WORKSPACE}/${INPUT_PKGDEST}"
test "$INPUT_PKGDEST" = '__INPUT_PATH__' && \
	export PKGDEST="$SRCDIR"

test "$INPUT_SRCPKGDEST" && \
	export SRCPKGDEST="${GITHUB_WORKSPACE}/${INPUT_SRCPKGDEST}"
test "$INPUT_SRCPKGDEST" = '__INPUT_PATH__' && \
	export SRCPKGDEST="$SRCDIR"

git config set --global --append safe.directory "$GITHUB_WORKSPACE"
git config set --global core.pager ''

# The default alpm user can't read our custom file-based databases...
sudo sed -i 's/DownloadUser = alpm/DownloadUser = runner/g' /etc/pacman.conf

glgrp "Initializing pacman keys"
sudo pacman-key --init
glgrpend

if [ "$INPUT_PACKAGER" ]; then
	glgrp "Adding packager information to makepkg configuration"
	printf 'PACKAGER="%s"\n' "$INPUT_PACKAGER" >> ~/.makepkg.conf
fi

if [ "$INPUT_PGP_KEY" ]; then
	glgrp "Importing PGP keys"
	"$SCRIPTS_PATH"/add-pacman-key.sh "$INPUT_PGP_KEY"
fi

if [ "$INPUT_PGP_KEYS" ]; then
	glgrp "Receiving PGP keys"
	for key in ${INPUT_PGP_KEYS//,/$'\n'}; do
		gpg --keyserver "$INPUT_PGP_KEYSERVER" --recv-keys "$key"
	done
fi

if [ "$INPUT_KEYRINGS" ]; then
	glgrp "Updating the keyring packages"
	sudo pacman -Syu --needed --noconfirm $INPUT_KEYRINGS
fi

export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
test "$INPUT_MOLD" = 'true' && export LDFLAGS="${LDFLAGS:+$LDFLAGS }-fuse-ld=mold"
test "$INPUT_NINJA" = 'true' && export CMAKE_GENERATOR=Ninja

# The order of repo entries matters. See `man 5 pacman.conf`.

if [ "$INPUT_CUSTOM_REPO_NAME" ]; then
	glgrp "Adding custom package repository $INPUT_CUSTOM_REPO_NAME"
	"$SCRIPTS_PATH"/add-custom-repo.sh \
		"$INPUT_CUSTOM_REPO_NAME" \
		"$INPUT_CUSTOM_REPO_URL" \
		"$INPUT_CUSTOM_REPO_SIGLEVEL"
fi

if [ "$INPUT_DEPENDENCIES_PATH" ]; then
	glgrp "Adding dependencies repository"
	"$SCRIPTS_PATH"/add-dependencies-repo.sh "$GITHUB_WORKSPACE/$INPUT_DEPENDENCIES_PATH"
fi


# Main

cd "${SRCDIR}" || exit 1

if [ "$INPUT_PKGVER" ]; then
	glgrp 'Updating pkgver of PKGBUILD'
	sed -i "s/^pkgver=.*$/pkgver=$INPUT_PKGVER/g" PKGBUILD
	git diff PKGBUILD
fi

if [ "$INPUT_PKGREL" ]; then
	glgrp 'Updating pkgrel of PKGBUILD'
	sed -i "s/^pkgrel=.*$/pkgrel=$INPUT_PKGREL/g" PKGBUILD
	git diff PKGBUILD
fi

if [ "$INPUT_UPDPKGSUMS" = 'true' ]; then
	glgrp 'Updating checksums on PKGBUILD'
	updpkgsums
	git diff PKGBUILD
fi

if [ "$INPUT_SRCINFO" = 'true' ] || [ "$INPUT_SRCINFO" = 'auto' -a -e .SRCINFO ] ; then
	glgrp "Generating new .SRCINFO based on PKGBUILD"
	makepkg --printsrcinfo > .SRCINFO
	git diff .SRCINFO
fi

if [ "$INPUT_NAMCAP" = 'true' ]; then
	glgrp 'Validating PKGBUILD with namcap'
	# shellcheck disable=2086
	namcap $INPUT_NAMCAP_OPTS PKGBUILD
fi

if [ "$INPUT_AUR" = 'true' ]; then
	glgrp 'Installing depends using yay'
	# shellcheck disable=1091
	source PKGBUILD
	yay -Syu --removemake --needed --noconfirm \
		"${depends[@]}" "${makedepends[@]}"
fi

if [ -e PKGBUILD ]; then
	# shellcheck disable=1091
	source PKGBUILD
	set +u
	test "$pkgbase" || pkgbase=''
	set -u
	gh_output pkgbase "$pkgbase"
	gh_output pkgname "$pkgname"
	gh_output pkgver "$pkgver"
	gh_output pkgrel "$pkgrel"
fi


# Build and Sign

if [ "$INPUT_MAKEPKG" = 'true' ]; then
	glgrp 'Running makepkg with options'
	# shellcheck disable=2086
	makepkg $INPUT_MAKEPKG_OPTS
fi

if [ "$INPUT_SIGNING_KEY" ]; then
	glgrp 'Signing packages'
	"$SCRIPTS_PATH"/sign-packages.sh "$PKGDEST" "$INPUT_SIGNING_KEY" \
		"$INPUT_SIGNING_KEY_PASSWORD"
fi


cd "$REPODIR" || exit 1

if [ "$INPUT_REPO_ADD_NAME" ]; then
	glgrp "Running repo-add"

	RA_DB="${INPUT_REPO_ADD_NAME}.db.tar"
	RA_EXT="$INPUT_REPO_ADD_EXT"
	test "$RA_EXT" && RA_DB="${RA_DB}.${RA_EXT}"
	RA_OPTS="$INPUT_REPO_ADD_OPTS"

	find . ! -name '*.sig' -name '*.pkg.tar*' -exec \
	    sh -c "repo-add $RA_OPTS \"$RA_DB\" \"\$@\" " sh {} +
fi

glgrpend
