SUBDIRS=hello_world
EXTRA=configure config.inc

all: clean
	for x in $(SUBDIRS) ; \
	do \
	cd $$x ; INCLUDEDIR=../.. ../../makeconf.sh ; ./configure && make ; \
	done

clean:
	for x in $(SUBDIRS) ; \
	do \
	cd $$x ; make clean ; rm -f $(EXTRA) ; \
	done
