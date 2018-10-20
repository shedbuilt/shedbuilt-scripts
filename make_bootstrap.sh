#!/bin/bash

# make_bootstrap
# Description: Sets up virtual file systems and Shedbuilt system repository on
# on the bootstrap partition, in preparation for system compilation in chroot.
# Example: ./make_bootstrap.sh https://github.com/shedbuilt blank sml/bootstrap_sun8i.sml /mnt/bootstrap

# Sanity Checks
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use 'sudo' if not logged in as root."
   exit 1
fi

if [ $# -lt 4 ]; then
   echo "Too few arguments to make_bootstrap"
   echo "Expected: make_bootstrap <system-repo-url> <system-repo-branch> <install-list> <install-root>"
   echo "Example: ./make_bootstrap.sh https://github.com/shedbuilt blank sml/bootstrap_sun8i.sml /mnt/bootstrap"
   exit 1
fi

SHED_BOOTSTRAP_INSTALLROOT="${4%/}"
SHED_BOOTSTRAP_SMLFILE=$(readlink -f -n "$3")
SHED_BOOTSTRAP_SMLFILE_NAME=$(basename "$SHED_BOOTSTRAP_SMLFILE")
SHED_BOOTSTRAP_REPO_BRANCH="$2"
SHED_BOOTSTRAP_REPO_BASEURL="${1%/}"

if [ ! -d "$SHED_BOOTSTRAP_INSTALLROOT" ]; then
    echo "Specified install root does not appear to be a directory: $SHED_BOOTSTRAP_INSTALLROOT"
    exit 1
fi

# Mount kernel virtual file systems at destination
if ! mount | grep -q "${SHED_BOOTSTRAP_INSTALLROOT}/sys"; then
    mkdir -pv "${SHED_BOOTSTRAP_INSTALLROOT}"/{dev,proc,sys,run} &&
    mknod -m 600 "${SHED_BOOTSTRAP_INSTALLROOT}/dev/console" c 5 1 &&
    mknod -m 666 "${SHED_BOOTSTRAP_INSTALLROOT}/dev/null" c 1 3 &&
    mount -v --bind /dev "${SHED_BOOTSTRAP_INSTALLROOT}/dev" &&
    mount -vt devpts devpts "${SHED_BOOTSTRAP_INSTALLROOT}/dev/pts" -o gid=5,mode=620 &&
    mount -vt proc proc "${SHED_BOOTSTRAP_INSTALLROOT}/proc" &&
    mount -vt sysfs sysfs "${SHED_BOOTSTRAP_INSTALLROOT}/sys" &&
    mount -vt tmpfs tmpfs "${SHED_BOOTSTRAP_INSTALLROOT}/run" || exit 1
    if [ -h "${SHED_BOOTSTRAP_INSTALLROOT}/dev/shm" ]; then
        mkdir -pv "${SHED_BOOTSTRAP_INSTALLROOT}"/$(readlink "${SHED_BOOTSTRAP_INSTALLROOT}/dev/shm") || exit 1
    fi
fi

# Install local bootstrap script and SML file
install -m755 bootstrap_shedbuilt.sh /tools &&
install -m644 "$SHED_BOOTSTRAP_SMLFILE" /tools || exit 1

# Create Shedbuilt system repository at destination
SHED_BOOTSTRAP_TMPDIR="${SHED_BOOTSTRAP_INSTALLROOT}/var/tmp/shedmake"
SHED_BOOTSTRAP_REPODIR="${SHED_BOOTSTRAP_INSTALLROOT}/var/shedmake/repos"
SHED_BOOTSTRAP_REMOTE_REPODIR="${SHED_BOOTSTRAP_REPODIR}/remote"
SHED_BOOTSTRAP_LOCAL_REPODIR="${SHED_BOOTSTRAP_REPODIR}/local"
SHED_BOOTSTRAP_LOCAL_REPO_NAME="default"
if [ ! -d "$SHED_BOOTSTRAP_TMPDIR" ]; then
    mkdir -pv "$SHED_BOOTSTRAP_TMPDIR" || exit 1
fi
if [ ! -d "$SHED_BOOTSTRAP_REMOTE_REPODIR" ]; then
    mkdir -pv "$SHED_BOOTSTRAP_REMOTE_REPODIR" || exit 1
fi
if [ ! -d "$SHED_BOOTSTRAP_LOCAL_REPODIR" ]; then
    mkdir -v "$SHED_BOOTSTRAP_LOCAL_REPODIR" || exit 1
fi
cd "$SHED_BOOTSTRAP_LOCAL_REPODIR"
if [ ! -d "$SHED_BOOTSTRAP_LOCAL_REPO_NAME" ]; then
    mkdir "$SHED_BOOTSTRAP_LOCAL_REPO_NAME" &&
    cd "$SHED_BOOTSTRAP_LOCAL_REPO_NAME" &&
    git init || exit 1
fi
cd "$SHED_BOOTSTRAP_REMOTE_REPODIR"
for SHED_BOOTSTRAP_REMOTE_REPO_NAME in audio communication development games graphics multimedia networking retrocomputing system utils video
do
    if [ ! -d "$SHED_BOOTSTRAP_REMOTE_REPO_NAME" ]; then
        git clone --branch "$SHED_BOOTSTRAP_REPO_BRANCH" --depth 1 --shallow-submodules "${SHED_BOOTSTRAP_REPO_BASEURL}/shedbuilt-${SHED_BOOTSTRAP_REMOTE_REPO_NAME}.git" "$SHED_BOOTSTRAP_REMOTE_REPO_NAME" &&
        cd "$SHED_BOOTSTRAP_REMOTE_REPO_NAME" &&
        git submodule init || exit 1
    else
        cd "$SHED_BOOTSTRAP_REMOTE_REPO_NAME" &&
        git pull || exit 1
    fi
    git submodule update || exit 1
    cd ..
done

# Cache all required source files
SHED_REMOTE_REPO_DIR="$SHED_BOOTSTRAP_REMOTE_REPODIR" shedmake fetch-source-list "/tools/${SHED_BOOTSTRAP_SMLFILE_NAME}" || exit 1

# Enter chroot and execute the bootstrap install script
chroot "$SHED_BOOTSTRAP_INSTALLROOT" /tools/bin/env -i \
            HOME=/root                  \
            TERM="$TERM"                \
            PS1='(bootstrap) \u:\w\$ '  \
            PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
            SHED_BOOTSTRAP_SMLFILE="/tools/${SHED_BOOTSTRAP_SMLFILE_NAME}" \
            /tools/bin/bash +h /tools/bootstrap_shedbuilt.sh

# Set up the swap file
dd if=/dev/zero of="${SHED_BOOTSTRAP_INSTALLROOT}/var/swap" bs=1M count=512
chmod 600 "${SHED_BOOTSTRAP_INSTALLROOT}/var/swap"
mkswap "${SHED_BOOTSTRAP_INSTALLROOT}/var/swap"
