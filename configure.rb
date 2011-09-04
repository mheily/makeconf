#!/usr/bin/env ruby
#
# Copyright (c) 2009-2011 Mark Heily <mark@heily.com>
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

#
# Abstraction for platform-specific system commands and variables
#
class Platform

  attr_reader :host_os, :target_os

  require 'rbconfig'

  def initialize(target_os = Config::CONFIG['host_os'])
    @host_os = Config::CONFIG['host_os']
    @target_os = target_os
  end

  def is_windows?
    @target_os =~ /mswin|mingw/ ? 1 : 0
  end

  def rm(path)
    if path.kind_of?(Array)
        path = path.join(' ')
    end
    if self.is_windows?
      return 'del /F ' + path
    else
      return 'rm -f ' + path
    end
  end
end

class Compiler
  attr_reader :ldflags, :cflags, :path

  def initialize(language, path, ldflags = "", cflags = "")
    @language = language
    @path = path
    @cflags = cflags
    @ldflags = ldflags
  end

  # Return the complete command line to compile an object
  def command(output,sources)
    [ @path, @cflags, sources.flatten, @ldadd ].join(' ')
  end
end

class CCompiler < Compiler
  def initialize()
    super('c','/usr/bin/cc')
  end
end

class Target
  def initialize(objs,deps = [],rules = [])
      @objs = objs
      @deps = deps
      @rules = rules
  end

  def add_dependency(depends)
    @deps.push(rule)
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def prepend_rule(target,rule)
    @rules.unshift(rule)
  end

  def to_s
    res = @objs + ':' + @deps.join(' ') + "\n" 
    @rules.flatten.each { |r| res += "\t" + r + "\n" }
    res
  end
end

class Makefile
  def initialize(platform)
    @platform = platform
    @vars = {}
    @targets = {}

    %w[all clean distclean install uninstall dist].each do |x|
        @targets[x] = Target.new(x)
    end
  end

  def define_variable(lval,op,rval)
    @vars[lval] = [ op, rval ]
  end

  def add_target(object,depends,rules)
    @targets[object] = Target.new(object,depends,rules)
  end

  def add_dependency(target,depends)
    @targets[target].add_depends(depends)
  end

  def add_deliverable(src,dst,rename = False)
    self.add_rule('install', '$(INSTALL) -m 644 ' + $src + ' $(DESTDIR)' + $dst)
    if (rename) 
      self.add_rule('uninstall', @platform.rm('$(DESTDIR)' + $dst))
    else 
      raise "FIXME"
#self.add_rule('uninstall', @platform.rm('$(DESTDIR)' + $dst + '/' . basename($src)));
    end 
  end

  def add_distributable(src)
    mode = '755' #TODO: test -x src, use 644 
    #FIXME:
    # self.add_rule('dist', "$(INSTALL) -m %{mode} %{src} %{self.distdir}")
  end

  def to_s
    res = "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n"
    @vars.sort.each { |x,y| res += x + y[0] + y[1] + "\n" }
    res += "\n\n"
    @targets.sort.each { |x,y| res += y.to_s }
    res
  end

end

class Project

#attr_reader :host_os, :target_os

  require 'yaml'

  def initialize(manifest)
    @ast = YAML.load_file('config.yaml')
    @cc = CCompiler.new
    @platform = Platform.new()
    @mf = Makefile.new(@platform)
    #puts @cc.command('a.out', [ 'blah.c' ])
    @mf.define_variable('CFLAGS', '=', 'todo')
    @mf.define_variable('LDFLAGS', '=', 'todo')
    @mf.define_variable('LDADD', '=', 'todo')
    @mf.define_variable('CC', '=', @cc.path)
#self.make_libraries
    puts @mf.to_s
  end

end

#######################################################################
#
#                               MAIN()
#

proj = Project.new('config.yaml')
