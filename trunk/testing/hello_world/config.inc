$project{'hello_world'} = {
        version => '0.1',
        cflags => "-Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600",
        tests   => [ 'hello' ],
        targets => {
            'libhello.so' => {
                sources => [ 'library.c' ],
            },
            'hello' => {
                depends => ['libhello.so'],
                sources => [qw(main.c extra.c)],
                ldflags => "-L . -rpath .",
                libs => "-lhello",
            },
        },
};

check_header('stdlib.h');
check_header(qw(stdio.h string.h does-not-exist.h));
check_symbol('fcntl.h', 'O_DOES_NOT_EXIST');
check_symbol('fcntl.h', 'O_RDWR');
check_symbol('pthread.h', 'pthread_exit');

1;
