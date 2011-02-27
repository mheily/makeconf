SUBDIRS=hello_world

all: clean
	for x in $(SUBDIRS) ; \
	do \
	cd $$x ; INCLUDEDIR=../.. ../../makeconf.sh ; ./configure && make && cat config.mk && make clean all check; \
	done

clean:
	for x in $(SUBDIRS) ; \
	do \
	cd $$x ; make clean || true ; rm -f configure ; \
	done
