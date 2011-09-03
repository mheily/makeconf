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

all: libhello.so.0.0

check: all

clean:
	rm -f libhello.so.0.0
	rm -f hello_world.pc

dist: all
	rm -f hello_world-0.1.tar.gz
	rm -rf hello_world-0.1
	mkdir hello_world-0.1
	$(INSTALL) -m 755 configure hello_world-0.1
	$(INSTALL) -m 644 config.yaml hello_world-0.1
	$(INSTALL) -m 644 library.c hello_world-0.1
	tar cf hello_world-0.1.tar hello_world-0.1
	gzip hello_world-0.1.tar
	rm -rf hello_world-0.1

distclean: clean
	rm -f Makefile config.h

install: all
	$(INSTALL) -m 644 libhello.so.0.0 $(DESTDIR)$(LIBDIR)
	$(LN) -sf libhello.so.0.0 $(DESTDIR)$(LIBDIR)/libhello.so.0
	$(LN) -sf libhello.so.0.0 $(DESTDIR)$(LIBDIR)/libhello.so

libhello.so.0.0: library.c
	$(CC) -o $@ -Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600 -shared -fPIC -fwhole-program $(LDFLAGS) library.c 

package: all

uninstall:
	rm $(DESTDIR)$(LIBDIR)/libhello.so.0.0
	rm $(DESTDIR)$(LIBDIR)/libhello.so.0
	rm $(DESTDIR)$(LIBDIR)/libhello.so
