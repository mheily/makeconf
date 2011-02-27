#
# Copyright (c) 2010 Mark Heily <mark@heily.com>
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

include config.mk

.PHONY :: install uninstall check dist dist-upload publish-www clean merge distclean fresh-build rpm edit cscope

all: makeconf

makeconf: makeconf.sh
	cat makeconf.sh | sed "s|^    INCLUDEDIR=.*|    INCLUDEDIR=\"$(INCLUDEDIR)/$(PROGRAM)\"|" > makeconf

install: makeconf
	$(INSTALL) -d -m 755 $(INCLUDEDIR)/$(PROGRAM)
	$(INSTALL) -m 644 configure config.inc.template $(INCLUDEDIR)/$(PROGRAM)
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -m 755 makeconf $(BINDIR)/makeconf

$(DISTFILE): $(SOURCES) $(HEADERS)
	mkdir $(PROGRAM)-$(VERSION)
	cp  Makefile ChangeLog configure config.inc      \
        $(MANS) $(EXTRA_DIST)   \
        $(PROGRAM)-$(VERSION)
	cp -R $(SUBDIRS) $(PROGRAM)-$(VERSION)
	rm -rf `find $(PROGRAM)-$(VERSION) -type d -name .svn -o -name .libs`
	cd $(PROGRAM)-$(VERSION) && ./configure && cd test && ./configure && cd .. && make distclean
	tar zcf $(PROGRAM)-$(VERSION).tar.gz $(PROGRAM)-$(VERSION)
	rm -rf $(PROGRAM)-$(VERSION)

# Dump a list of all variables
dump:
	@echo "$(PREFIX) $(LIBDIR) $(BINDIR) $(SBINDIR) $(INCLUDEDIR)"
                  
dist:
	rm -f $(DISTFILE)
	make $(DISTFILE)

dist-upload: $(DISTFILE)
	scp $(DISTFILE) $(DIST)

clean:
	rm -f makeconf
	rm -rf pkg

check:
	cd testing && make

distclean: clean
	rm -f *.tar.gz config.mk config.h $(PROGRAM).pc $(PROGRAM).la rpm.spec
	rm -rf $(PROGRAM)-$(VERSION) 2>/dev/null || true

fresh-build:
	rm -rf /tmp/$(PROGRAM)-testbuild 
	svn co svn://mark.heily.com/libkqueue/trunk /tmp/$(PROGRAM)-testbuild 
	cd /tmp/$(PROGRAM)-testbuild && ./configure && make check
	rm -rf /tmp/$(PROGRAM)-testbuild 

merge:
	svn diff $(REPOSITORY)/branches/stable $(REPOSITORY)/trunk | gvim -
	@printf "Merge changes from the trunk to the stable branch [y/N]? "
	@read x && test "$$x" = "y"
	echo "ok"

tags: $(SOURCES) $(HEADERS)
	ctags $(SOURCES) $(HEADERS)

edit: tags
	$(EDITOR) $(SOURCES) $(HEADERS)
    
cscope: tags
	cscope $(SOURCES) $(HEADERS)

# Creates an ~/rpmbuild tree
rpmbuild:
	mkdir -p $$HOME/rpmbuild
	cd $$HOME/rpmbuild && mkdir -p BUILD RPMS SOURCES SPECS SRPMS
	grep _topdir $$HOME/.rpmmacros || \
           echo "%_topdir %(echo $$HOME/rpmbuild)" >> $$HOME/.rpmmacros

rpm: rpmbuild clean $(DISTFILE)
	mkdir -p pkg
	cp $(DISTFILE) $$HOME/rpmbuild/SOURCES 
	rpmbuild -bb rpm.spec
	find $$HOME/rpmbuild -name '$(PROGRAM)-$(VERSION)*.rpm' -exec mv {} ./pkg \;

deb: clean $(DISTFILE)
	mkdir pkg && cd pkg ; \
	tar zxf ../$(DISTFILE) ; \
	cp ../$(DISTFILE) $(PROGRAM)_$(VERSION).orig.tar.gz ; \
	cp -R ../ports/debian $(PROGRAM)-$(VERSION) ; \
	rm -rf `find $(PROGRAM)-$(VERSION)/debian -type d -name .svn` ; \
	perl -pi -e 's/\@\@VERSION\@\@/$(VERSION)/' $(PROGRAM)-$(VERSION)/debian/changelog ; \
	cd $(PROGRAM)-$(VERSION) && dpkg-buildpackage -uc -us
	lintian -i pkg/*.deb
	@printf "\nThe following packages have been created:\n"
	@find ./pkg -name '*.deb' | sed 's/^/    /'

debug-install:
	./configure --prefix=/usr --debug=yes
	make clean && make && sudo make install

diff:
	if [ "`pwd | grep /trunk`" != "" ] ; then \
	   (cd .. ; $(DIFF) branches/stable trunk | less) ; \
    fi
	if [ "`pwd | grep /branches/stable`" != "" ] ; then \
	   (cd ../.. ; $(DIFF) branches/stable trunk | less) ; \
    fi

# Used for testing on a Solaris guest VM
#
solaris-test:
	make dist && scp -P 2222 libkqueue-$(VERSION).tar.gz localhost:/tmp && ssh -p 2222 localhost ". .profile ; cd /tmp ; rm -rf libkqueue-$(VERSION) ; gtar zxvf libkqueue-$(VERSION).tar.gz && cd libkqueue-$(VERSION) && ./configure && make && make check"
