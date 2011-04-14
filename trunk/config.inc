
$project{'makeconf'} = {
        version => '0.1',
        extra_dist => [ qw(testing/Makefile) ],
        install => {
            '$(BINDIR)' => [ qw(makeconf) ],
#XXX-FIXME
#            '$(INCLUDEDIR)/makeconf' => [ '-d -m 755' ],
#	$(INSTALL) -m 644 configure config.inc.template $(INCLUDEDIR)/$(PROGRAM)
#	$(INSTALL) -d -m 755 $(BINDIR)
#	$(INSTALL) -m 755 makeconf $(BINDIR)/makeconf
        },
};

1;
