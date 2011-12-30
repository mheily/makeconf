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

$LOAD_PATH << '../../lib'

require 'makeconf'

mc = Makeconf.new
p = Project.new(:id => 'libpthread_workqueue', :version => '0.8.2')
p.mount 'http://mark.heily.com/sites/mark.heily.com/files/libpthread_workqueue-0.8.2.tar.gz', 'libpthread_workqueue'
__END__
  :id => 'libpthread_workqueue',
  :version => '0.8.2',
  :license => 'BSD',
  :author => 'Mark Heily',
  :summary => 'pthread_workqueue library',
  :description => 'pthread_workqueue library',
  :extra_dist => ['LICENSE', 'src/*.[ch]', 'src/*/*.[ch]'],
  :manpages => 'pthread_workqueue.3',
  :headers => 'pthread_workqueue.h',
  :libraries => {
     'libpthread_workqueue' => {
        :cflags => cflags,
        :sources => sources,
        :ldadd => ldadd,
        },
  },
  :tests => {
    'api' => {
        :sources => [ 'testing/api/test.c' ],
        :ldadd => ['-lpthread_workqueue', ldadd ]
        },
    'latency' => {
        :sources => [ 'testing/latency/latency.c' ],
        :ldadd => ['-lpthread_workqueue', ldadd ]
    },
    'witem_cache' => {
        :sources => [ 'testing/witem_cache/test.c' ],
        :ldadd => ['-lpthread_workqueue', ldadd ]
    },
  }
)

#pre_configure_hook() {
#  if [ "$debug" = "yes" ] ; then
#      cflags="$cflags -g3 -O0 -DPTHREAD_WORKQUEUE_DEBUG -rdynamic"
#  else
#      cflags="$cflags -g -O2"
#  fi
#}
