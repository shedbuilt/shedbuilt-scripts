#!/bin/bash

# make_bootstrap
# Description: Sets up virtual file systems and Shedbuilt system repository on
# on the bootstrap partition, in preparation for system compilation in chroot.
# Example: ./make_bootstrap.sh https://github.com/shedbuilt/shedbuilt-system.git blank bootstrap_sun8i.sml /mnt/shedstrap

if [ $# -lt 4 ]; then
   echo "Too few arguments to make_bootstrap"
   echo "Expected: make_bootstrap <system-repo-url> <release> <install-list> <install-root>"
   exit 1
fi

INSTALL_ROOT="${4%/}"
export BOOTSTRAP_SMLFILE="$3"
SYSRELEASE="$2"
SYSREPOURL="$1"

# Mount kernel virtual file systems at destination
if ! mount | grep -q "${INSTALL_ROOT}/sys"; then
    mkdir -pv "${INSTALL_ROOT}"/{dev,proc,sys,run}
    mknod -m 600 "${INSTALL_ROOT}/dev/console" c 5 1
    mknod -m 666 "${INSTALL_ROOT}/dev/null" c 1 3
    mount -v --bind /dev "${INSTALL_ROOT}/dev"
    mount -vt devpts devpts "${INSTALL_ROOT}/dev/pts" -o gid=5,mode=620
    mount -vt proc proc "${INSTALL_ROOT}/proc"
    mount -vt sysfs sysfs "${INSTALL_ROOT}/sys"
    mount -vt tmpfs tmpfs "${INSTALL_ROOT}/run"
    if [ -h "${INSTALL_ROOT}/dev/shm" ]; then
        mkdir -pv "${INSTALL_ROOT}"/$(readlink "${INSTALL_ROOT}/dev/shm")
    fi
fi

# Install local bootstrap script
install -m755 bootstrap_shedbuilt.sh /tools
# Create Shedbuilt system repository at destination
TMPDIR="${INSTALL_ROOT}/var/tmp"
REPODIR="${INSTALL_ROOT}/var/shedmake/repos"
REMOTEREPODIR="${REPODIR}/remote"
LOCALREPODIR="${REPODIR}/local"
SYSREPONAME="system"
LOCALREPONAME="default"
mkdir -pv "$TMPDIR"
mkdir -pv "$REMOTEREPODIR"
mkdir -v "$LOCALREPODIR"
cd "$LOCALREPODIR"
mkdir "$LOCALREPONAME"
cd "$LOCALREPONAME"
git init
cd "$REMOTEREPODIR"
if [ ! -d "$SYSREPONAME" ]; then
    git clone "$SYSREPOURL" "$SYSREPONAME" && \
    cd "$SYSREPONAME" && \
    git checkout "$SYSRELEASE" && \
    git submodule init || exit 1
else
    cd "$SYSREPONAME" && \
    git pull || exit 1
fi
git submodule update || exit 1

# Cache all required source files
shedmake fetch-source-list "$BOOTSTRAPSMLFILE" || exit 1

# Enter chroot and execute the bootstrap install script
chroot "$INSTALL_ROOT" /tools/bin/env -i \
            HOME=/root                  \
            TERM="$TERM"                \
            PS1='(bootstrap) \u:\w\$ '  \
            PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
            BOOTSTRAP_SMLFILE="$BOOTSTRAP_SMLFILE" \
            /tools/bin/bash +h /tools/bootstrap_shedbuilt.sh

# Set up the swap file
dd if=/dev/zero of="${INSTALL_ROOT}/var/swap" bs=1M count=512
chmod 600 "${INSTALL_ROOT}/var/swap"
mkswap "${INSTALL_ROOT}/var/swap"
