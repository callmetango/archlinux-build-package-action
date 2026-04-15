#!/bin/bash

set -e -u

log_group() {
	printf "::group::${1}\n"
}

log_endgroup() {
	printf "::endgroup::\n"
}

# Set path
HOME=/home/builder
echo "::group::Copying files from $GITHUB_WORKSPACE to $HOME/work"
cd $HOME
mkdir work
cd work

if [[ -n $INPUT_PGPKEYS ]]; then
  echo "::group::Loading PGP keys"
  for key in ${INPUT_PGPKEYS//,/$'\n'}; do
    gpg --keyserver $INPUT_PGPKEYSERVER --recv-keys $key
  done
  echo "::endgroup::"
fi

# If there is a custom path, we need to copy the whole repository
# because we run "git diff" at several stages and without the entire
# tree the output will be incorrect.
log_group "Copying PKGBUILD"
if [[ -n $INPUT_PATH ]]; then
  cp -rTfv "$GITHUB_WORKSPACE"/ ./
  cd $INPUT_PATH
else
  # Without a custom path though, we can just grab the .git directory and the PKGBUILD.
  cp -rfv "$GITHUB_WORKSPACE"/.git ./
  cp -fv "$GITHUB_WORKSPACE"/PKGBUILD ./
fi
log_endgroup

if [ -n $INPUT_REPONAME ] && [ -d "/github/workspace/$INPUT_REPOPATH" ]; then
    log_group "Adding local package repository"
    cat <<<EOF >> /etc/pacman.conf

[$INPUT_REPONAME]
Server = "file:///github/workspace/$INPUT_REPOPATH"
SigLevel = Optional
EOF
    log_endgroup
fi

# Update archlinux-keyring
if [[ $INPUT_ARCHLINUX_KEYRING == true ]]; then
    echo "::group::Updating archlinux-keyring"
    sudo pacman -Syu --noconfirm archlinux-keyring
    echo "::endgroup::"
fi

# Update pkgver
if [[ -n $INPUT_PKGVER ]]; then
    echo "::group::Updating pkgver on PKGBUILD"
    sed -i "s:^pkgver=.*$:pkgver=$INPUT_PKGVER:g" PKGBUILD
    git --no-pager diff PKGBUILD
    echo "::endgroup::"
fi

# Update pkgrel
if [[ -n $INPUT_PKGREL ]]; then
    echo "::group::Updating pkgrel on PKGBUILD"
    sed -i "s:^pkgrel=.*$:pkgrel=$INPUT_PKGREL:g" PKGBUILD
    git --no-pager diff PKGBUILD
    echo "::endgroup::"
fi

# Update checksums
if [[ $INPUT_UPDPKGSUMS == true ]]; then
    echo "::group::Updating checksums on PKGBUILD"
    updpkgsums
    git --no-pager diff PKGBUILD
    echo "::endgroup::"
fi

# Generate .SRCINFO
if [[ $INPUT_SRCINFO == true ]]; then
    echo "::group::Generating new .SRCINFO based on PKGBUILD"
    makepkg --printsrcinfo >.SRCINFO
    git --no-pager diff .SRCINFO
    echo "::endgroup::"
fi

# Validate with namcap
if [[ $INPUT_NAMCAP == true ]]; then
    echo "::group::Validating PKGBUILD with namcap"
    namcap -i PKGBUILD
    echo "::endgroup::"
fi

# Install depends using yay from aur
if [[ $INPUT_AUR == true ]]; then
    echo "::group::Installing depends using yay"
    source PKGBUILD
    yay -Syu --removemake --needed --noconfirm "${depends[@]}" "${makedepends[@]}"
    echo "::endgroup::"
fi

if [[ -n $INPUT_FLAGS ]]; then
    log_group "Running makepkg with flags"
    makepkg $INPUT_FLAGS
    log_endgroup
fi

if [ -n "$INPUT_REPONAME" } ; then
    REPOPATH="$GITHUB_WORKSPACE/$INPUT_REPOPATH"
    REPOPATH=${REPOPATH%/}

    log_group "Adding package to repo"
    repo-add "$INPUT_REPONAME".db.tar.zst "$REPOPATH"/*.pkg.* *.pkg.*
    log_endgroup
fi

WORKPATH=$GITHUB_WORKSPACE/$INPUT_PATH
WORKPATH=${WORKPATH%/}
echo "::group::Copying files from $HOME/work to $WORKPATH"
sudo cp -fv PKGBUILD "$WORKPATH"/PKGBUILD
if [[ -e .SRCINFO ]]; then
    sudo cp -fv .SRCINFO "$WORKPATH"/.SRCINFO
fi

sudo cp -fv *.pkg* "$WORKPATH"/

if [ -n $INPUT_REPONAME ]; then
    REPOPATH="$GITHUB_WORKSPACE/$INPUT_REPOPATH"
    REPOPATH=${REPOPATH%/}
    sudo cp -fv *$INPUT_REPONAME".db* "$REPOPATH"
fi

echo "::endgroup::"
