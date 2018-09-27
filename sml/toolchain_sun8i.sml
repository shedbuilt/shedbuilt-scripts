binutils --target armv7l-shedstrap-linux-gnueabihf
gcc --target armv7l-shedstrap-linux-gnueabihf --ignore-dependencies --skip-preinstall --jobs 1
linux-headers --target armv7l-shedstrap-linux-gnueabihf
glibc --host armv7l-shedstrap-linux-gnueabihf --skip-postinstall
libstdcpp --host armv7l-shedstrap-linux-gnueabihf
binutils --host armv7l-shedstrap-linux-gnueabihf --jobs 1 --force
gcc --host armv7l-shedstrap-linux-gnueabihf --ignore-dependencies --skip-preinstall --jobs 1 --force
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
m4
make
patch
perl
sed
tar
texinfo
util-linux --skip-preinstall
xz --skip-preinstall
shedmake
