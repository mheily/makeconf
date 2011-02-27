program="hello_world"
version="0.1"
cflags="-fpic -Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600"
targets="hello:main.c,extra.c libhello.so:library.c"
ldflags=""
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
