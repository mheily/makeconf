include config.mk

test-install:
	mkdir -p foo/usr/local/bin foo/usr/local/lib
	make install DESTDIR=./foo
	find foo
	rm -rf foo
