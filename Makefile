VERSION=0.1.0

# Exclude these classes from the documentation
RDOC_EXCLUDE=-x gui.rb -x wxapp

.PHONY: gem check doc

default: clean check gem

gem: makeconf-$(VERSION).gem

makeconf-$(VERSION).gem: test
	gem build makeconf.gemspec

check:
	rake test

doc:
	rm -rf doc
	rdoc $(RDOC_EXCLUDE) --main=makeconf --title makeconf lib
	chromium -new ./doc/index.html &

distclean clean:
	rm -f *.gem

edit:
	$(EDITOR) lib/*.rb lib/makeconf/*.rb
