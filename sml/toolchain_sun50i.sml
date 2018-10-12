binutils --target aarch64-shedstrap-linux-gnu
gcc --target aarch64-shedstrap-linux-gnu --ignore-dependencies --skip-preinstall --jobs 1
linux-headers --target aarch64-shedstrap-linux-gnu
glibc --host aarch64-shedstrap-linux-gnu --skip-postinstall
libstdcpp --host aarch64-shedstrap-linux-gnu
binutils --host aarch64-shedstrap-linux-gnu --jobs 1 --force
gcc --host aarch64-shedstrap-linux-gnu --ignore-dependencies --skip-preinstall --jobs 1 --force
m4
ncurses
bash
bison
bzip2
coreutils
diffutils
file
findutils
gawk
gettext
grep
gzip
make
patch
perl
sed
tar
texinfo
util-linux --skip-preinstall
xz --skip-preinstall
shedmake
