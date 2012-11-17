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

mc = Makeconf.new :minimum_version => 0.1

mc.project = Project.new \
    :id => 'simple', 
    :version => 1.0

mc.project.add Binary.new \
    :id => 'hello', 
    :sources => %w{main.c}

mc.project.ac_check_header 'stdio.h'
mc.project.ac_check_header 'does-not-exist.h'
mc.project.ac_check_decl 'exit'
mc.project.ac_check_decl 'symbol_that_does_not_exist'
mc.project.ac_check_funcs 'read'
mc.project.ac_check_funcs 'epoll_create', :include => 'sys/epoll.h'
mc.project.ac_check_funcs 'fgetln'
mc.project.ac_check_funcs 'getline'
mc.project.ac_check_funcs 'kqueue'
mc.project.ac_check_funcs 'port_create'

mc.configure

#check_symbol:
#    fcntl.h: [ O_DOES_NOT_EXIST, O_RDWR ]
#    pthread.h: [ pthread_exit ]
