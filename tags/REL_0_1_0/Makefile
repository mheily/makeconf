default: all

all:
	gem build makeconf.gemspec

distclean clean:
	rm -f *.gem

edit:
	$(EDITOR) lib/*.rb lib/makeconf/*.rb
