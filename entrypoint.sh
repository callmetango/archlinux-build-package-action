#!/bin/bash

set -e -u

. /github-log.sh

REPOPATH="$GITHUB_WORKSPACE/$INPUT_REPOPATH"
REPOPATH=${REPOPATH%/}

# Set path
HOME=/home/builder
BUILDDIR="$HOME"/work
glgrp "Copying files from $GITHUB_WORKSPACE to $BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

if [[ -n $INPUT_PGPKEYS ]]; then
  glgrp "Loading PGP keys"
  for key in ${INPUT_PGPKEYS//,/$'\n'}; do
    gpg --keyserver $INPUT_PGPKEYSERVER --recv-keys $key
  done
fi

# If there is a custom path, we need to copy the whole repository
# because we run "git diff" at several stages and without the entire
# tree the output will be incorrect.
glgrp "Copying PKGBUILD"
if [[ -n $INPUT_PATH ]]; then
  cp -rTfv "$GITHUB_WORKSPACE"/ ./
  cd $INPUT_PATH
else
  # Without a custom path though, we can just grab the .git directory and the PKGBUILD.
  cp -rfv "$GITHUB_WORKSPACE"/.git ./
  cp -fv "$GITHUB_WORKSPACE"/PKGBUILD ./
fi

if [ -n $INPUT_REPONAME ] && [ -f "${REPOPATH}/${INPUT_REPONAME}.db" ]; then
    glgrp "Adding local package repository"
    sudo tee /etc/pacman.conf <<- EOF
		[$INPUT_REPONAME]
		Server = file:///github/workspace/$INPUT_REPOPATH
		SigLevel = Optional
EOF
fi

# Update archlinux-keyring
if [[ $INPUT_ARCHLINUX_KEYRING == true ]]; then
    glgrp "Updating archlinux-keyring"
    sudo pacman -Syu --noconfirm archlinux-keyring
fi

# Update pkgver
if [[ -n $INPUT_PKGVER ]]; then
    glgrp "Updating pkgver on PKGBUILD"
    sed -i "s:^pkgver=.*$:pkgver=$INPUT_PKGVER:g" PKGBUILD
    git --no-pager diff PKGBUILD
fi

# Update pkgrel
if [[ -n $INPUT_PKGREL ]]; then
    glgrp "Updating pkgrel on PKGBUILD"
    sed -i "s:^pkgrel=.*$:pkgrel=$INPUT_PKGREL:g" PKGBUILD
    git --no-pager diff PKGBUILD
fi

# Update checksums
if [[ $INPUT_UPDPKGSUMS == true ]]; then
    glgrp "Updating checksums on PKGBUILD"
    updpkgsums
    git --no-pager diff PKGBUILD
fi

if [[ $INPUT_SRCINFO == true ]]; then
    glgrp "Generating new .SRCINFO based on PKGBUILD"
    makepkg --printsrcinfo >.SRCINFO
    git --no-pager diff .SRCINFO
fi

if [[ $INPUT_NAMCAP == true ]]; then
    glgrp "Validating PKGBUILD with namcap"
    namcap -i PKGBUILD
fi

# Install depends using yay from aur
if [[ $INPUT_AUR == true ]]; then
    glgrp "Installing depends using yay"
    source PKGBUILD
    yay -Syu --removemake --needed --noconfirm "${depends[@]}" "${makedepends[@]}"
fi

if [[ -n $INPUT_FLAGS ]]; then
    glgrp "Running makepkg with flags"
    makepkg $INPUT_FLAGS
fi

source PKGBUILD
echo "PKGVER=$pkgver" | sudo tee -a "$GITHUB_ENV"
echo "PKGREL=$pkgrel" | sudo tee -a "$GITHUB_ENV"

WORKPATH=$GITHUB_WORKSPACE/$INPUT_PATH
WORKPATH=${WORKPATH%/}
glgrp "Copying files from $BUILDDIR to $WORKPATH"
sudo cp -fv PKGBUILD "$WORKPATH"/PKGBUILD
if [[ -e .SRCINFO ]]; then
    sudo cp -fv .SRCINFO "$WORKPATH"/.SRCINFO
fi

sudo cp -fv *.pkg* "$WORKPATH"/

if [ -n $INPUT_REPONAME ]; then
    glgrp "Adding package to repo"
    REPOPATH="$GITHUB_WORKSPACE/$INPUT_REPOPATH"
    REPOPATH=${REPOPATH%/}
    sudo repo-add "$REPOPATH"/"$INPUT_REPONAME.db$INPUT_REPOEXT" *.pkg.*
fi

glend
