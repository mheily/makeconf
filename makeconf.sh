#!/bin/sh
#
# Copyright (c) 2011 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

if [ "$INCLUDEDIR" = "" ] ; then
    INCLUDEDIR="/usr/include/makeconf"
fi

err() {
    echo "ERROR: $*"
    exit 1
}

src="$INCLUDEDIR/configure"
dst="./configure"
if [ -f "$dst" ]
then
    err "$dst already exists"
fi
if [ -f "$src" ]
then
    cp $src .
    chmod 755 ./configure
else
    err "$src does not exist"
fi

if [ ! -f Makefile ] 
then
    echo "include config.mk
    " > Makefile
fi

if [ ! -f config.inc ] 
then
    cp $INCLUDEDIR/config.inc.template config.inc \
        || err "unable to create config.inc"
fi
