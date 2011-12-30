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

Gem::Specification.new do |s|
  s.name        = 'makeconf'
  s.version     = '0.1.0'
  s.date        = '2011-12-30'
  s.summary     = 'Generates configurable Makefiles'
  s.description = 'An alternative to GNU autoconf/automake/libtool/etc'
  s.authors     = ['Mark Heily']
  s.email       = 'mark@heily.com'
  s.files       = ['lib/makeconf.rb'].concat(Dir.glob('lib/makeconf/*.rb'))
  s.homepage    = 'http://mark.heily.com/project/makeconf'
end
