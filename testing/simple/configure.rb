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

p = Project.new \
    :id => 'simple', 
    :version => 1.0

cpu_cflags = Makefile::Conditional.new('CFLAGS')
cpu_cflags.ifeq('$(HOST_CPU)', { 'i686' => '-m32', 'x86_64' => '-m64', :default => 'ERROR-UNKNOWN-CPU' })
p.add cpu_cflags

cpu_ldflags = Makefile::Conditional.new('LDFLAGS')
cpu_ldflags.ifeq('$(HOST_CPU)', { 'i686' => '-m32', 'x86_64' => '-m64', :default => 'ERROR-UNKNOWN-CPU' })
p.add cpu_ldflags

p.add(
    Binary.new(
    :id => 'hello', 
    :cflags => [ '-Dfoo=bar' ],
    :sources => %w{main.c}
    )
 )

p.check_header 'stdio.h'
p.check_header 'does-not-exist.h'
p.check_decl 'pthread_create', :include => 'pthread.h'
#p.check_decl 'exit'
#p.check_decl 'symbol_that_does_not_exist'
#p.check_function 'read'
#p.check_function 'epoll_create', :include => 'sys/epoll.h'
#p.check_function 'fgetln'
#p.check_function 'getline'
#p.check_function 'kqueue'
#p.check_function 'port_create'

mc = Makeconf.new :minimum_version => 0.1
mc.configure(p)

#check_symbol:
#    fcntl.h: [ O_DOES_NOT_EXIST, O_RDWR ]
#    pthread.h: [ pthread_exit ]
