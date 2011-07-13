makeconf::project->new(
        id => 'makeconf',
        version => '0.1',
        extra_dist => [ qw(testing/Makefile) ],
        scripts => {
            'makeconf' => {
                dest => 'bindir',
                mode => '0755',
            },
        },
        install => [ 
            '-d -m 755 -o foo -g bar $pkgincludedir',
            '-m 0755 makeconf $bindir',
            '-m 0644 configure config.inc.template $pkgincludedir',
            ],
        );

1;
