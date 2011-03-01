$project{'makeconf'} = {
        version => '0.1',
        ldflags => '-Wl,-rpath,/opt/foo',
        binary => {
            'foo' => {
                sources => ['main.c'],
            },
        },
};

check_header('stdlib.h');
check_header(qw(stdio.h string.h does-not-exist.h));
check_symbol('fcntl.h', 'O_DOES_NOT_EXIST');
check_symbol('fcntl.h', 'O_RDWR');
check_symbol('pthread.h', 'pthread_exit');

1;