#!/bin/bash

# make_toolchain
# Description: Pulls packaging for the bootstrap toolchain from
# the repository, then compiles and installs the toolchain to the
# designated install root.
# Example: sudo ./make_toolchain.sh https://github.com/shedbuilt/shedbuilt-toolchain.git blank toolchain_sun8i.sml /mnt/shedstrap

# Sanity Checks
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use 'sudo' if not logged in as root."
   exit 1
fi

if [ $# -lt 4 ]; then
   echo "Too few arguments to install_shedbuilt_toolchain"
   echo "Usage: make_toolchain <repo-url> <repo-branch> <install-list> <install-root>"
   echo "Example: sudo ./make_toolchain.sh https://github.com/shedbuilt/shedbuilt-toolchain.git blank toolchain_sun8i.sml /mnt/shedstrap"
   exit 1
fi

# Configuration
TOOLCHAIN_REPO="$1"
RELEASE_BRANCH="$2"
TOOLCHAIN_SMLFILE="$3"
INSTALL_ROOT="${4%/}"

# Create Shedbuilt toolchain repo at destination
PKGDIR="${RELEASE_BRANCH}-toolchain"
cd "$INSTALL_ROOT"
if [ ! -d $PKGDIR ]; then
    git clone "$TOOLCHAIN_REPO" $PKGDIR
    cd $PKGDIR
    git checkout "$RELEASE_BRANCH"
    git submodule init
else
    cd $PKGDIR
    git pull
fi
git submodule update

# Create symlink
if [ ! -L /tools ]; then
    mkdir -v "${INSTALL_ROOT}/tools"
    ln -sv "${INSTALL_ROOT}/tools" /
fi

# Set environment variables
set +h
umask 022
LC_ALL=POSIX
if [[ ":${PATH}:" != *":/tools/bin:"* ]]; then
    PATH="/tools/bin:${PATH}"
fi
export LC_ALL PATH

# Install toolchain packages
shedmake install-list "$TOOLCHAIN_SMLFILE" --options 'toolchain !docs'   \
                                      --install-root "$INSTALL_ROOT" \
                                      --verbose || exit 1

# Strip binaries and remove man and info pages
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
