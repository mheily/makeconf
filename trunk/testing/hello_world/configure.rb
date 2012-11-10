#!/usr/bin/env ruby
#
# Copyright (c) 2011 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

$VERBOSE = true

require 'makeconf'

project = Project.new(
  :id => 'testing',
  :version => '1.0'
)

project.add(
  Library.new(
      :id => 'hello', 
      :cflags => '-Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600',
      :sources => 'library.c'
      ),

  Binary.new(
    :id => 'hello', 
    :cflags => '-Dabc=def',
    :sources => %w{main.c extra.c},
    :ldadd => '-lhello'
  ),

  Test.new(
    :id => 'check-hello', 
    :cflags => '-Dabc=def',
    :sources => %w{main.c extra.c},
    :ldadd => '-lhello'
  )
)

Makeconf.configure(project)

#DEADWOOD
#Makeconf.configure(
#    :project => 'hello_world',
#    :version => '0.1',
#    :libraries => {
#      'libhello' => {
#        :cflags => '-Wall -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600',
#        :sources => [ 'library.c' ],
#        },
#    },
#    :binaries => {
#       'hello' => {
#            :sources => [ 'main.c', 'extra.c' ],
#            :ldflags => '-L . -rpath .',
#        :ldadd => '-lhello',
#        :depends => [ 'libhello.so.0.0' ],
##        install => {
##            '$(LIBDIR)' => [ '-m 644', 'libhello.so' ],
##            '$(BINDIR)' => [ '-m 755', 'hello' ], 
##        },
#        },
#    }
#)

# TODO:
#check_header: [ stdlib.h, stdio.h, string.h, does-not-exist.h ]
#check_symbol:
#    fcntl.h: [ O_DOES_NOT_EXIST, O_RDWR ]
#    pthread.h: [ pthread_exit ]
#        )
