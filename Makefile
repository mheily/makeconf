API=posix
AR=/usr/bin/ar
BINDIR=$(PREFIX)/bin
CC=/usr/bin/cc
CFLAGS=
INCLUDEDIR=$(PREFIX)/include
INSTALL=/usr/bin/install
LDADD=
LDFLAGS=
LIBDIR=$(PREFIX)/lib
LN=/bin/ln
MANDIR=$(PREFIX)/share/man
PREFIX=/usr/local
SBINDIR=$(PREFIX)/sbin
TAR=/bin/tar
TARGET=linux
VERSION=0.1

default: all

all:

check: all

clean:

dist: all
	rm -f makeconf-0.1.tar.gz
	rm -rf makeconf-0.1
	mkdir makeconf-0.1
	$(INSTALL) -m 755 configure makeconf-0.1
	$(INSTALL) -m 644 config.yaml makeconf-0.1
	tar cf makeconf-0.1.tar makeconf-0.1
	gzip makeconf-0.1.tar
	rm -rf makeconf-0.1

distclean: clean
	rm -f Makefile config.h

install: all

package: all

uninstall:
