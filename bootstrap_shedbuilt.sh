#!/tools/bin/bash

# Install all packages
shedmake install-list "/var/shedmake/repos/remote/system/${BOOTSTRAP_SMLFILE}" \
                      --verbose || exit 1

# Remove static libraries
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a
