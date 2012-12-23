VERSION=0.1.0

# Exclude these classes from the documentation
RDOC_EXCLUDE=-x gui.rb -x wxapp

.PHONY: gem check doc

default: clean check gem

gem: makeconf-$(VERSION).gem

makeconf-$(VERSION).gem: test
	gem build makeconf.gemspec

check:
	#FIXME:rake test
	cd testing/hello_world && rm -f configure && ../../bin/makeconf && RUBYLIB=../../lib ./configure && make check && ./check-hello


doc:
	rm -rf doc
	rdoc $(RDOC_EXCLUDE) --main=makeconf --title makeconf lib
	chromium -new ./doc/index.html &

distclean clean:
	rm -f *.gem

# View the project website
view-www:
	cd www && webgen
	firefox www/output/index.html

# Sync the project website
sync-www:
	cd www && webgen
	rsync -av --delete www/output/ web.sourceforge.net:/home/project-web/makeconf/htdocs/

edit:
	$(EDITOR) lib/*.rb lib/makeconf/*.rb
