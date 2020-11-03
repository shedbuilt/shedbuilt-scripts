#!/bin/bash

# make_release_image.sh
# Create a Shedbuilt img file for a specific device, suitable for installation on an SD card.
# Exmaple: ./make_release_image.sh https://github.com/shedbuilt blank sml/release_sun8i.sml orangepipc 2G shedbuilt_blank-1_orangepipc.img /mnt/shedarchive

if [ $# -lt 6 ]; then
   echo "Too few arguments to make_release_image"
   echo "Expected: make_release_image.sh <repo-baseurl> <repo-branch> <install-list> <device-option> <size> <image-filename> <cachedir>"
fi

SHDREL_SYSREPOURL="${1%/}"
SHDREL_SYSRELEASE="$2"
SHDREL_SMLFILE=$(readlink -f -n "$3")
SHDREL_DEVICE="$4"
SHDREL_IMGSIZE="$5"
SHDREL_IMGFILE="$6"
SHDREL_WORKDIR="${7%/}"
SHDREL_IMGNAME=$(basename "$SHDREL_IMGFILE" .img)
SHDREL_MOUNT=/mnt/${SHDREL_IMGNAME}

# Set parameters for Rockchip and Allwinner devices
if [ "$SHDREL_DEVICE" == 'rock64' ]; then
    SHEDREL_BOOTLOADER_OFFSET='64'
    SHEDREL_PARTITION_START_SECTOR='32768'
else
    SHEDREL_BOOTLOADER_OFFSET='16'
    SHEDREL_PARTITION_START_SECTOR='4096'
fi

# Create local caches
SHDREL_SRCDIR="${SHDREL_WORKDIR}/source"
SHDREL_BINDIR="${SHDREL_WORKDIR}/binary"
SHDREL_UBOOTDIR="${SHDREL_WORKDIR}/u-boot"
if [ ! -d "$SHDREL_SRCDIR" ]; then
    mkdir "$SHDREL_SRCDIR" || exit 1
fi
if [ ! -d "$SHDREL_BINDIR" ]; then
    mkdir "$SHDREL_BINDIR" || exit 1
fi
if [ ! -d "$SHDREL_UBOOTDIR" ]; then
    mkdir "$SHDREL_UBOOTDIR" || exit 1
fi

# Create mount point
if [ ! -d "$SHDREL_MOUNT" ]; then
    mkdir "$SHDREL_MOUNT" || exit 1
fi

# Create and mount an image file
touch "$SHDREL_IMGFILE" &&
fallocate -z -l ${SHDREL_IMGSIZE} "$SHDREL_IMGFILE" &&
SHDREL_LOOPDEV=$(losetup -P -f --show "$SHDREL_IMGFILE") || exit 1
(
echo o # Create a new empty DOS partition table
echo n # Add a new partition
echo p # Primary partition
echo 1 # Partition number
echo 4096 # First sector
echo # Last sector (Accept default: end of device)
echo w # Write changes
) | fdisk ${SHDREL_LOOPDEV} &&
mkfs -v -t ext4 ${SHDREL_LOOPDEV}p1 &&
mount ${SHDREL_LOOPDEV}p1 "$SHDREL_MOUNT" || exit 1

# Mount kernel virtual file systems at destination
if ! mount | grep -q "${SHDREL_MOUNT}/sys"; then
    mkdir -pv "${SHDREL_MOUNT}"/{dev,proc,sys,run} &&
    mknod -m 600 "${SHDREL_MOUNT}/dev/console" c 5 1 &&
    mknod -m 666 "${SHDREL_MOUNT}/dev/null" c 1 3 &&
    mount -v --bind /dev "${SHDREL_MOUNT}/dev" &&
    mount -vt devpts devpts "${SHDREL_MOUNT}/dev/pts" -o gid=5,mode=620 &&
    mount -vt proc proc "${SHDREL_MOUNT}/proc" &&
    mount -vt sysfs sysfs "${SHDREL_MOUNT}/sys" &&
    mount -vt tmpfs tmpfs "${SHDREL_MOUNT}/run" || exit 1
    if [ -h "${SHDREL_MOUNT}/dev/shm" ]; then
        mkdir -pv "${SHDREL_MOUNT}"/$(readlink "${SHDREL_MOUNT}/dev/shm") || exit 1
    fi
fi

# Create Shedbuilt system repository at destination
SHDREL_SHEDMAKEDIR="${SHDREL_MOUNT}/var/shedmake"
SHDREL_TMPDIR="${SHDREL_MOUNT}/var/tmp/shedmake"
SHDREL_REPODIR="${SHDREL_SHEDMAKEDIR}/repos"
SHDREL_REMOTE_REPODIR="${SHDREL_REPODIR}/remote"
SHDREL_LOCAL_REPODIR="${SHDREL_REPODIR}/local"
SHDREL_LOCAL_REPO_NAME="default"
SHDREL_SYSTEM_REPO_NAME="system"
mkdir -pv "$SHDREL_TMPDIR" &&
mkdir -pv "$SHDREL_REMOTE_REPODIR" &&
mkdir -v "$SHDREL_LOCAL_REPODIR" &&
chgrp -v shedmake "$SHDREL_LOCAL_REPODIR" &&
chmod -v 775 "$SHDREL_LOCAL_REPODIR" &&
chmod -v g+s "$SHDREL_LOCAL_REPODIR" &&
chgrp -v shedmake "$SHDREL_TMPDIR" &&
chmod -v 775 "$SHDREL_TMPDIR" || exit 1
cd "$SHDREL_LOCAL_REPODIR"
if [ ! -d "$SHDREL_LOCAL_REPO_NAME" ]; then
    mkdir -v "$SHDREL_LOCAL_REPO_NAME" &&
    cd "$SHDREL_LOCAL_REPO_NAME" &&
    git init || exit 1
fi
cd "$SHDREL_REMOTE_REPODIR"
for SHDREL_REMOTE_REPO_NAME in audio communication desktop development games graphics multimedia networking retrocomputing system utils video
do
    if [ ! -d "$SHDREL_REMOTE_REPO_NAME" ]; then
        git clone --branch "$SHDREL_SYSRELEASE" --depth 1 --shallow-submodules "${SHDREL_SYSREPOURL}/shedbuilt-${SHDREL_REMOTE_REPO_NAME}.git" "$SHDREL_REMOTE_REPO_NAME" &&
        cd "$SHDREL_REMOTE_REPO_NAME" &&
        git submodule init || exit 1
    else
        cd "$SHDREL_REMOTE_REPO_NAME" &&
        git pull || exit 1
    fi
    git submodule update || exit 1
    cd ..
done

# Install all system packages
SHED_REMOTE_REPO_DIR="$SHDREL_REMOTE_REPODIR" shedmake install-list "$SHDREL_SMLFILE" \
    --options 'release docs'" $SHDREL_DEVICE" \
    --install-root "$SHDREL_MOUNT" \
    --ignore-dependencies \
    --cache-source \
    --source-dir "$SHDREL_SRCDIR" \
    --cache-binary \
    --binary-dir "$SHDREL_BINDIR" \
    --verbose || exit 1

# Install root user skeleton
cd "$SHDREL_MOUNT"/etc/skel
shopt -s globstar nullglob dotglob
for DEFAULT_FILE in **; do
    if [ -d "$DEFAULT_FILE" ]; then
        continue
    fi
    install -m644 "$DEFAULT_FILE" "$SHDREL_MOUNT"/root
done
shopt -u globstar nullglob dotglob

# Copy out u-boot binary and unmount all filesystems
SHDREL_UBOOT_BIN_PATH=$(ls "$SHDREL_MOUNT"/boot/u-boot/*_${SHDREL_DEVICE}.bin)
SHDREL_UBOOT_BIN_FILE=$(basename "$SHDREL_UBOOT_BIN_PATH")
cd "$SHDREL_WORKDIR" &&
cp "$SHDREL_UBOOT_BIN_PATH" "$SHDREL_UBOOTDIR" &&
umount -v "$SHDREL_MOUNT"/dev/pts &&
umount -v "$SHDREL_MOUNT"/dev &&
umount -v "$SHDREL_MOUNT"/run &&
umount -v "$SHDREL_MOUNT"/proc &&
umount -v "$SHDREL_MOUNT"/sys &&
umount -v "$SHDREL_MOUNT" &&
rmdir "$SHDREL_MOUNT" &&

# Install bootloader
dd if="${SHDREL_UBOOTDIR}/${SHDREL_UBOOT_BIN_FILE}" of=${SHDREL_LOOPDEV} seek=${SHEDREL_BOOTLOADER_OFFSET} &&
sync &&
losetup -d ${SHDREL_LOOPDEV}
