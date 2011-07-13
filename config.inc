$project{'makeconf'} = {
        version => '0.1',
        extra_dist => [ qw(testing/Makefile) ],
        scripts => {
            'makeconf' => {
                dest => 'bindir',
                mode => '0755',
            },
        },
        data => [ 'pkgincludedir', [qw(configure config.inc.template)] ],
};

1;
