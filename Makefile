VERSION=0.1.0

# Exclude these classes from the documentation
RDOC_EXCLUDE=-x gui.rb -x wxapp

.PHONY: gem check doc www

default: clean check gem

gem: makeconf-$(VERSION).gem

makeconf-$(VERSION).gem: test
	gem build makeconf.gemspec

check:
	#FIXME:rake test
	cd testing/hello_world && rm -f configure && ../../bin/makeconf && RUBYLIB=../../lib ./configure && make check && ./check-hello


doc:
	chromium -new ./doc/index.html &

distclean clean:
	rm -f *.gem

# View the project website
www:
	cd www && webgen
	rdoc $(RDOC_EXCLUDE) -f ri -o www/output/api-reference --main=makeconf --title makeconf lib
	firefox www/output/index.html

# Sync the project website
sync-www:
	cd www && webgen
	rm -rf www/api-reference
	rsync -av --delete www/output/ web.sourceforge.net:/home/project-web/makeconf/htdocs/

edit:
	$(EDITOR) lib/*.rb lib/makeconf/*.rb
