#!/tools/bin/bash

# Install all packages
shedmake install-list "$SHED_BOOTSTRAP_SMLFILE" \
                      --verbose || exit 1

# Remove static libraries
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a

# Install root user skeleton
cd /etc/skel
shopt -s globstar nullglob dotglob
for DEFAULT_FILE in **; do
    if [ -d "$DEFAULT_FILE" ]; then
        continue
    fi
    install -m644 "$DEFAULT_FILE" /root
done
shopt -u globstar nullglob dotglob
