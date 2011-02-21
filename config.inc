program="makeconf"
version="0.1"
abi_major="0"
abi_minor="0"
abi_version="$abi_major.$abi_minor"
cflags="-fpic -Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600"
ldflags=""
sources="" 
libdepends=""
deps=""
mans=""
headers=""
extra_dist=""
subdirs=""

# Package metadata
pkg_summary="makeconf"
pkg_description="makeconf"
license="BSD"
author="Mark Heily"

pre_configure_hook() {
    return
}

post_configure_hook() {
    return
}
