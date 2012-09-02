VERSION=0.1.0

.PHONY: gem check

default: clean check gem

gem: makeconf-$(VERSION).gem

makeconf-$(VERSION).gem: test
	gem build makeconf.gemspec

check:
	rake test

distclean clean:
	rm -f *.gem

edit:
	$(EDITOR) lib/*.rb lib/makeconf/*.rb
