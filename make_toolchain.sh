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

if [ $# -lt 5 ]; then
   echo "Too few arguments to make_toolchain"
   echo "Usage: make_toolchain <repo-url> <repo-branch> <install-list> <device-option> <install-root>"
   echo "Example: sudo ./make_toolchain.sh https://github.com/shedbuilt/shedbuilt-toolchain.git blank toolchain_sun8i.sml nanopineo /mnt/bootstrap"
   exit 1
fi

SHED_TOOLCHAIN_REPO="$1"
SHED_TOOLCHAIN_BRANCH="$2"
SHED_TOOLCHAIN_SMLFILE="$3"
SHED_TOOLCHAIN_DEVICE="$4"
SHED_TOOLCHAIN_INSTALLROOT="${5%/}"

if [ ! -d "$SHED_TOOLCHAIN_INSTALLROOT" ]; then
    echo "Specified install root does not appear to be a directory: $SHED_TOOLCHAIN_INSTALLROOT"
    exit 1
fi

# Create Shedbuilt toolchain repo at destination
PKGDIR="${SHED_TOOLCHAIN_BRANCH}-toolchain"
cd "$SHED_TOOLCHAIN_INSTALLROOT"
if [ ! -d $PKGDIR ]; then
    git clone "$SHED_TOOLCHAIN_REPO" $PKGDIR &&
    cd $PKGDIR &&
    git checkout "$SHED_TOOLCHAIN_BRANCH" &&
    git submodule init || exit 1
else
    cd $PKGDIR &&
    git pull || exit 1
fi
git submodule update || exit 1

# Create symlink
if [ ! -L /tools ]; then
    mkdir -v "${SHED_TOOLCHAIN_INSTALLROOT}/tools" &&
    ln -sv "${SHED_TOOLCHAIN_INSTALLROOT}/tools" / || exit 1
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
shedmake install-list "$SHED_TOOLCHAIN_SMLFILE" --options 'toolchain !docs'" $SHED_TOOLCHAIN_DEVICE" \   \
                                      --install-root "$SHED_TOOLCHAIN_INSTALLROOT" \
                                      --verbose || exit 1

# Strip binaries and remove man and info pages
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
