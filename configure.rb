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
    @target_os =~ /mswin|mingw/
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

  def cp(src,dst)
    if self.is_windows?
      return "copy #{src} #{dst}"
    else
      return "cp #{src} #{dst}"
    end
  end

  def dev_null
    self.is_windows? ? ' >NUL 2>NUL' : ' >/dev/null 2>&1'
  end

  # The extension used for executable files 
  def executable_extension
    self.is_windows? ? '.exe' : ''
  end

end

class Compiler
  require 'tempfile'
  attr_reader :ldflags, :cflags, :path
  attr_accessor :platform

  def initialize(platform, language, extension, ldflags = "", cflags = "", ldadd = "")
    @platform = platform
    @language = language
    @extension = extension
    @cflags = cflags
    @ldflags = ldflags
    @ldadd = ldadd
  end

  # Search for a suitable compiler
  def search(path)
    res = nil
    printf "checking for a " + @language + " compiler.. "
    if (path)
      res = path
#  else if ENV['CC']
#      res = 'CC'
    else
      throw 'fixme'
    end
    puts res
    @path = res
  end

  # Return the complete command line to compile an object
  def command(output,sources,log_to = "", compile_only = 0)
    cflags = @cflags
    cflags += ' -c' if compile_only == 1
    cflags += ' -o ' + output
    sources = sources.flatten if sources.kind_of?(Array)
    [ @path, cflags, sources, @ldadd, log_to ].join(' ')
  end

  # Compile a test program
  def test_compile(code)
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
    objfile = f.path + '.out'
    cmd = command(objfile, f.path, @platform.dev_null, 1)
#puts ' + ' + cmd + "\n"
    rc = system cmd
    File.unlink(objfile) if rc
    return rc
  end
end

class CCompiler < Compiler
  def initialize(platform)
    super(platform, 'C', '.c')
    search('/usr/bin/cc')
  end
end

class Target
  def initialize(objs,deps = [],rules = [])
      @objs = objs
      @deps = deps
      @rules = rules
  end

  def add_dependency(depends)
    @deps.push(depends)
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def prepend_rule(target,rule)
    @rules.unshift(rule)
  end

  def to_s
    res = "\n" + @objs + ':'
    res += ' ' + @deps.join(' ') if @deps
    res += "\n"
    @rules.each { |r| res += "\t" + r + "\n" }
    res
  end
end

class Makefile
  def initialize(platform, project, version)
    @platform = platform
    @project = project
    @version = version
    @vars = {}
    @targets = {}

    %w[all clean distclean install uninstall distdir].each do |x|
        @targets[x] = Target.new(x)
    end
  end

  def define_variable(lval,op,rval)
    @vars[lval] = [ op, rval ]
  end

  def add_target(object,depends,rules)
    @targets[object] = Target.new(object,depends,rules)
  end

  def add_rule(target, rule)
    @targets[target].add_rule(rule)
  end

  # Add a file to the tarball during 'make dist'
  def distribute(path)
    @targets['distdir'].add_rule(@platform.cp(path, '$(distdir)'))
  end

  # Add a file to be removed during 'make clean'
  def clean(path)
    @targets['clean'].add_rule(@platform.rm(path))
  end

  def add_dependency(target,depends)
    @targets[target].add_dependency(depends)
  end

  def add_deliverable(src,dst,rename = False)
    add_rule('install', '$(INSTALL) -m 644 ' + $src + ' $(DESTDIR)' + $dst)
    if (rename) 
      add_rule('uninstall', @platform.rm('$(DESTDIR)' + $dst))
    else 
      raise "FIXME"
#add_rule('uninstall', @platform.rm('$(DESTDIR)' + $dst + '/' . basename($src)));
    end 
  end

  def add_distributable(src)
    mode = '755' #TODO: test -x src, use 644 
    #FIXME:
    # add_rule('dist', "$(INSTALL) -m %{mode} %{src} %{self.distdir}")
  end

  def to_s
    res = ''
    make_dist
    @vars.sort.each { |x,y| res += x + y[0] + y[1] + "\n" }
    res += "\n\n"
    res += "default: all\n"
    @targets.sort.each { |x,y| res += y.to_s }
    res
  end

  private

  def make_dist
    distdir = @project + '-' + @version
    tg = Target.new('dist')
    tg.add_rule("rm -rf " + distdir)
    tg.add_rule("mkdir " + distdir)
    tg.add_rule('$(MAKE) distdir distdir=' + distdir)
    @targets['dist'] = tg
  end

end

# A buildable object like a library or executable
class Buildable

  def initialize(id, ast, compiler, makefile)
    @id = id
    @ast = ast
    @compiler = compiler
    @makefile = makefile
    default = {
        'output' => id,
        'cflags' => '', # TODO: pull from project
        'ldflags' => '', # TODO: pull from project
        'ldadd' => '', # TODO: pull from project
        'sources' => [],
        'depends' => [],
    }
    default.each do |k,v| 
      instance_variable_set('@' + k, ast[k].nil? ? v : ast[k])
    end
  end

  def build
    @makefile.clean(@output)
    @makefile.distribute(@sources)
    @makefile.add_dependency('all', @output)
  end

end

class Library < Buildable

  def initialize(id, ast, compiler, makefile)
    super(id, ast, compiler, makefile)
    default = {
        'abi_major' => '0',
        'abi_minor' => '0',
        'enable_shared' => True,
        'enable_static' => True,
        'headers' => [],
    }
    default.each do |k,v| 
      instance_variable_set(k, ast[k].nil? ? default[k] : ast[k])
    end
  end
end

# An executable binary file
class Binary < Buildable

  def initialize(id, ast, compiler, makefile)
    super(id, ast, compiler, makefile)
  end

  def build
    binfile = @id + @compiler.platform.executable_extension
    @makefile.add_target(binfile, @depends, @compiler.command(binfile, @sources))
    super()
  end
          
end

class Header

  def initialize(path, compiler)
    @path = path
    @compiler = compiler
    @exists = check_exists
  end

  def check_exists
    printf "checking for #{@path}... "
    rc = @compiler.test_compile("#include <" + @path + ">")
    puts rc ? 'yes' : 'no'
    rc
  end

  def exists?
    @exists
  end

  def to_config_h
     id = @path.upcase.gsub(%r{[.-]}, '_')
     if @exists
       "#define HAVE_" + id + " 1\n"
     else
       "#undef  HAVE_" + id + "\n" 
     end
  end
     
end

class Project

  require 'yaml'

  def initialize(manifest)
    @ast = YAML.load_file('config.yaml')
    @platform = Platform.new()
    @cc = CCompiler.new(@platform)
    @mf = Makefile.new(@platform, @ast['project'], @ast['version'].to_s)
    @header = {}
    
    # Define Makefile variables
    @mf.define_variable('MAKE', '=', 'make')
    @mf.define_variable('CFLAGS', '=', 'todo')
    @mf.define_variable('LDFLAGS', '=', 'todo')
    @mf.define_variable('LDADD', '=', 'todo')
    @mf.define_variable('CC', '=', @cc.path)

    # Validate the AST
    %w[libraries binaries].each { |x| @ast[x] ||= [] }

    check_headers
    make_libraries
    make_binaries
    write_config_h
    write_makefile
  end

  private

  def check_headers
    @ast['check_header'].each do |h|
        @header[h] = Header.new(h, @cc)
     end
  end

  def make_libraries
    @ast['libraries'].each do |k,v|
        Library.new(k, v, @cc, @mf).build
    end
  end

  def make_binaries
    @ast['binaries'].each do |k,v|
        Binary.new(k, v, @cc, @mf).build
    end
  end

  def write_makefile
    puts 'writing Makefile'
    f = File.open('Makefile', 'w')
    f.print "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n"
    f.print @mf.to_s
    f.close
  end

  def write_config_h
    puts 'Creating config.h'
    f = File.open('config.h', 'w')
    f.print "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n"
    @header.each { |k,v| f.print v.to_config_h }
    f.close
  end

end

#######################################################################
#
#                               MAIN()
#

proj = Project.new('config.yaml')