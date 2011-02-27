hello_DEPENDS=libhello.so
hello_LDFLAGS=-L. -Wl,-rpath,.
hello_LDADD=-lhello

include config.mk

check: hello
#LD_LIBRARY_PATH=. ./hello
	./hello
