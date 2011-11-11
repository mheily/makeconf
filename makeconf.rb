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

class Makeconf

  require 'optparse'

  def initialize(manifest = 'config.yaml')
    @manifest = manifest
    @installer = Installer.new()
  end

  def parse_options(args = ARGV)
     opts = OptionParser.new do |opts|
       opts.banner = 'Usage: configure [options]'

       @installer.parse_options(opts)

       opts.separator ''
       opts.separator 'Common options:'

       opts.on_tail('-h', '--help', 'Show this message') do
         puts opts
          exit
       end

       opts.on_tail('-V', '--version', 'Display version information and exit') do
         puts OptionParser::Version.join('.')
         exit
       end
    end

    opts.parse!(args)
  end

  def configure
     @proj = Project.new(@manifest)

     parse_options
     @proj.installer = @installer
  end

  # Write all output files
  def finalize
    @proj.finalize
  end

end

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

  # Returns true or false depending on if the target is MS Windows
  def is_windows?
    @target_os =~ /mswin|mingw/
  end

  def archiver(archive,members)
    if self.is_windows? && ! ENV['MSYSTEM']
      'lib.exe ' + members.join(' ') + ' /OUT:' + archive
    else
      # TODO: add '/usr/bin/strip --strip-unneeded' + archive
      'ar rs ' + archive + ' ' + members.join(' ')
   end
  end

  def rm(path)
    if path.kind_of?(Array)
        path = path.join(' ')
    end
    if self.is_windows? && ! ENV['MSYSTEM']
      return 'del /F ' + path
    else
      return 'rm -f ' + path
    end
  end

  def cp(src,dst)
    if src.kind_of?(Array)
      src = src.join(' ')
    end

    if self.is_windows? && ! ENV['MSYSTEM']
      return "copy #{src} #{dst}"
    else
      return "cp #{src} #{dst}"
    end
  end

  def dev_null
    if self.is_windows? && ! ENV['MSYSTEM'] 
      ' >NUL 2>NUL' 
    else
      ' >/dev/null 2>&1'
    end
  end

  # The extension used for executable files 
  def executable_extension
    self.is_windows? ? '.exe' : ''
  end

  # The extension used for intermediate object files 
  def object_extension
    self.is_windows? ? '.obj' : '.o'
  end

  # The extension used for static libraries
  def static_library_extension
    self.is_windows? ? '.lib' : '.a'
  end

  # The extension used for shared libraries
  def shared_library_extension(abi_major,abi_minor)
    self.is_windows? ? '.dll' : '.so.' + abi_major + '.' + abi_minor
  end

  # Emulate the which(1) command
  def which(command)
    return nil if self.is_windows?      # FIXME: STUB
    ENV['PATH'].split(':').each do |prefix|
      path = prefix + '/' + command
      return command if File.executable?(path)
    end
    nil
  end

end

# An installer copies files from the current directory to an OS-wide location
class Installer

  attr_accessor :prefix, :bindir, :sbindir, :libdir, :includedir, :mandir

  def initialize()
    @items = []

    printf "checking for a BSD-compatible install.. "
    @path = search() or throw 'No installer found'
    printf @path + "\n"

    # Set default installation paths
    @prefix = '/usr/local'
    @bindir = '$(PREFIX)/bin'
    @sbindir = '$(PREFIX)/sbin'
    @libdir = '$(PREFIX)/lib'
    @includedir = '$(PREFIX)/include'
    @mandir = '$(PREFIX)/man'
  end

  # Parse command line options.
  # Should only be called from Makeconf.parse_options()
  def parse_options(opts)
    opts.separator ""
    opts.separator "Installation options:"

    directories.each do |dir|
       opts.on('--' + dir + ' [DIRECTORY]', 'FIXME') do |arg|
          instance_variable_set('@' + dir, arg)
       end
    end

  end

  # Return a list of configurable installation directories
  def directories
    %w[prefix bindir sbindir libdir includedir mandir].sort
  end

  # Register a file to be copied during the 'make install' phase.
  def install(src,dst,mode = nil)
  end

  # Return a hash of variables to be included in a Makefile
  def makefile_variables()
    res = { 'INSTALL' => @path }
    directories.each do |x|
      res[x.upcase] = instance_variable_get('@' + x)
    end
    return res
  end

  private

  def search()
    [ ENV['INSTALL'], '/usr/ucb/install', '/usr/bin/install' ].each do |x|
        if !x.nil? and File.exists?(x)
         return x
        end
    end
  end

end

# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  # Constructor for the Linker class
  # === Parameters
  # * _platform_ - The target platform
  #
  def initialize(platform)
    @platform = platform
    @flags = []
  end

  # Sets the ELF soname to the specified string
  def soname(s)
    unless @platform.is_windows?
     @flags.push ['soname', s]
    end
  end

  # Add all symbols to the dynamic symbol table (GNU ld only)
  def export_dynamic
     @flags.push 'export-dynamic'
  end

  # Returns the linker flags suitable for passing to the compiler
  def to_s
     tok = []
     @flags.each do |f|
        if f.kind_of?(Array)
          tok.push '-Wl,-' + f[0] + ',' + f[1]
        else
          tok.push '-Wl,-' + f
        end
     end
     return ' ' + tok.join(' ')
  end
end

# Processes source code files to produce intermediate object files.
#
class Compiler

  require 'tempfile'
  attr_reader :ldflags, :cflags, :path
  attr_accessor :platform, :is_library, :is_shared, :is_makefile, :sources

  def initialize(platform, language, extension, ldflags = '', cflags = '', ldadd = '')
    @platform = platform
    @language = language
    @extension = extension
    @cflags = cflags
    @ldflags = ldflags
    @ldadd = ldadd
    @is_library = false
    @is_shared = false
    @is_makefile = false        # if true, the output will be customized for use in a Makefile
    @ld = Linker.new(platform)
  end

  def clone
    Marshal.load(Marshal.dump(self))
  end

  def linker
    @ld
  end

  # Search for a suitable compiler
  def search(compilers)
    res = nil
    printf "checking for a " + @language + " compiler.. "
    if ENV['CC']
      res = ENV['CC']
    else
      compilers.each do |command|
         if @platform.which(command)
           res = command
           break
         end
      end
    end

    # FIXME: kludge for Windows, breaks mingw
    if @platform.is_windows?
        res = 'cl.exe'
    end

    throw 'No compiler found' if res.nil? || res == ''

    if @platform.is_windows? && res.match(/cl.exe/i)
        help = ' /? <NUL'
    else
        help = ' --help'
    end
    
    # Verify the command can be executed
    cmd = res + help + @platform.dev_null
    unless system(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    @path = res
  end

  # Return the intermediate object files for each source file
  def objs
    o = @platform.object_extension
    @sources.map { |s| s.sub(/.c$/, ((!@is_library or @is_shared) ? o : '-static' + o)) }
  end

  # Return the complete command line to compile an object
  def command(output, extra_cflags = "", log_to = "")
    cflags = @cflags + extra_cflags
    cflags += ' -c'
    cflags += ' -fPIC' if @is_library and @is_shared

    # Add the linker flags to CFLAGS
    cflags += @ld.to_s

    # FIXME: we are letting the caller add these to Makefile targets ??
    unless @is_makefile
      if @path.match(/cl.exe$/i)
        cflags += ' /Fo' + output
      else
        cflags += ' -o ' + output
      end
    end

    # KLUDGE: remove things that CL.EXE doesn't understand
    if @path.match(/cl.exe$/i)
      cflags += ' '
      cflags.gsub!(/ -Wall /, ' ') #  /Wall generates too much noise
      cflags.gsub!(/ -Werror /, ' ')  # Could use /WX here
      cflags.gsub!(/ -W /, ' ')
      cflags.gsub!(/ -Wno-.*? /, ' ')
      cflags.gsub!(/ -Wextra /, ' ')
      cflags.gsub!(/ -fPIC /, ' ')
      cflags.gsub!(/ -std=.*? /, ' ')
      cflags.gsub!(/ -pedantic /, ' ')
    end

    if sources.kind_of?(Array)
      inputs = @sources
    else
      inputs = [ @sources ] 
    end
    throw 'One or more sources are required' unless inputs.count

    # In a Makefile command, the sources are not listed explicitly
    if @is_makefile
      inputs = ''
    end
       
    [ @path, cflags, inputs, @ldadd, log_to ].join(' ')
  end

  # Compile a test program
  def test_compile(code)
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
    objfile = f.path + '.out'
    cmd = command(objfile, f.path, @platform.dev_null)
#puts ' + ' + cmd + "\n"
    rc = system cmd
    File.unlink(objfile) if rc
    return rc
  end

  # Generate the Makefile targets for each translation unit
  # XXX-THIS IS BROKEN DUE TO REFACTORING
  def add_targets(mf,prefix = '')
    throw 'Invalid parameter' unless mf.kind_of?(Makefile)
    deps = objs.sort
    deps.each do |d| 
      src = d.sub(/#{@platform.object_extension}$/, '.c')
      output = @platform.is_windows? ? ' /Fo' + d : ' -o ' + d
      cmd = command(d, cflags = @cflags)
      mf.add_target(d, src, cmd + output + ' ' + src) 
    end
  end
end

class CCompiler < Compiler

  attr_accessor :output_type

  def initialize(platform)
    @output_type = nil
    super(platform, 'C', '.c')
    search(['cc', 'gcc', 'clang', 'cl.exe'])
  end

end

class Target
  def initialize(objs, deps = [], rules = [])
      deps = [ deps ] unless deps.kind_of?(Array)
      rules = [ rules ] unless rules.kind_of?(Array)
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

# A Makefile is a collection of targets and rules used to build software.
#
class Makefile
  
  # Object constructor.
  # === Parameters
  # * _platform_ - The target platform
  # * _project_ - The name of the project
  # * _version_ - The version number of the project
  #  
  def initialize(platform, project, version)
    @platform = platform
    @project = project
    @version = version
    @vars = {}
    @targets = {}

    %w[all clean distclean install uninstall distdir].each do |x|
        @targets[x] = Target.new(objs = x)
    end

    # Prepare the destination tree for 'make install'
    @targets['install'].add_rule('test -z $(DESTDIR) || test -e $(DESTDIR)')
    @targets['install'].add_rule('for x in $(BINDIR) $(SBINDIR) $(LIBDIR) ; do test -e $(DESTDIR)$$x || $(INSTALL) -d -m 755 $(DESTDIR)$$x ; done')

    # Distribute some standard files with 'make distdir'
    ['makeconf.rb', 'config.yaml', 'configure'].each { |f| distribute(f) }
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

  # Add a file to be installed during 'make install'
  def install(src,dst,opt = {})
    rename = opt.has_key?('rename') ? opt['rename'] : false
    mode = opt.has_key?('mode') ? opt['mode'] : '644'
    add_rule('install', "$(INSTALL) -m #{mode} #{src} $(DESTDIR)#{dst}")
    add_rule('uninstall', @platform.rm("$(DESTDIR)#{dst}/#{File.basename(src)}"))

    # FIXME: broken
#   if (rename) 
#      add_rule('uninstall', @platform.rm('$(DESTDIR)' + dst))
#    else 
#      raise "FIXME"
##add_rule('uninstall', @platform.rm('$(DESTDIR)' + $dst + '/' . basename($src)));
#    end 
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
    if @platform.is_windows? 
       raise 'FIXME - Not implemented'
    else
       tg.add_rule("rm -rf #{distdir}.tar #{distdir}.tar.gz")
       tg.add_rule("tar cvf #{distdir}.tar #{distdir}")
       tg.add_rule("gzip #{distdir}.tar")
       tg.add_rule("rm -rf #{distdir}")
       clean("#{distdir}.tar.gz")
    end
    @targets['dist'] = tg
  end

end

# A buildable object like a library or executable
class Buildable

  def initialize(id, ast, compiler, makefile)
    @id = id
    @ast = ast
    @compiler = compiler.clone
    @makefile = makefile
    @output = []
    default = {
        'extension' => '',
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
        'enable_shared' => true,
        'enable_static' => true,
        'headers' => [],
    }
    default.each do |k,v| 
      instance_variable_set('@' + k, ast[k].nil? ? default[k] : ast[k])
    end
  end

  def build
    build_static_library
    build_shared_library
    super()
  end

  private

  def build_static_library
    libfile = @id + @compiler.platform.static_library_extension
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = false
    cc.is_makefile = true
    cc.sources = @sources
    cmd = cc.command(libfile, cflags = @cflags)
    deps = cc.objs.sort
    deps.each do |d| 
      src = d.sub(/-static#{@compiler.platform.object_extension}$/, '.c')
      output = @compiler.platform.is_windows? ? ' /Fo' + d : ' -o ' + d
      @makefile.add_target(d, src, cmd + output + ' ' + src) 
    end
    @makefile.add_target(libfile, deps, @compiler.platform.archiver(libfile, deps))
    @makefile.clean(cc.objs)
    @output.push libfile
  end

  def build_shared_library
    libfile = @id + @compiler.platform.shared_library_extension(@abi_major,@abi_minor)
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = true
    cc.is_makefile = true
    cc.sources = @sources
    cc.add_targets(@makefile)

    deps = cc.objs.sort

    if @compiler.platform.is_windows?
      @makefile.add_target(libfile, deps, 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
      # FIXME: shouldn't we use cmd to build the dll ??
    else
      # Build the linker flags
      ld = Linker.new(@compiler.platform)
      ld.export_dynamic
      ld.soname(@id + '.' + @abi_major)

      # Build the complete compiler string
      # (FIXME) should use Compiler method here
      tok = [ '$(CC)', '-shared', '-o $@' ]
      tok.push ld.to_s
      tok += deps
      @makefile.add_target(libfile, deps, tok.join(' '))
    end 
    @makefile.clean(cc.objs)
    @output.push libfile
  end

end

# An executable binary file
class Binary < Buildable

  def initialize(id, ast, compiler, makefile)
    super(id, ast, compiler, makefile)
  end

  def build
    binfile = @id + @compiler.platform.executable_extension
    cc = @compiler.clone
    cc.is_library = false
    cc.is_makefile = true
    cc.sources = @sources
    cc.add_targets(@makefile)

    # Build the complete compiler string
    # (FIXME) should use Compiler method here
    deps = cc.objs.sort
    tok = [ '$(CC)', '-o $@' ]
    tok += deps
    @makefile.add_target(binfile, @depends + deps, tok.join(' '))

    @makefile.clean(cc.objs)
    @makefile.install(binfile, '$(BINDIR)')
    @output.push binfile
    super()
  end
          
end

# A script file, written in an interpreted language like Perl/Ruby/Python
#
class Script

  def initialize(id, ast, makefile)
    @id = id
    @ast = ast
    @makefile = makefile
    @output = []
    default = {
        'sources' => [],
        'dest' => '$(BINDIR)',
        'mode' => '755',
    }
    default.each do |k,v| 
      instance_variable_set('@' + k, ast[k].nil? ? v : ast[k])
    end
  end

  def build
    @makefile.distribute(@sources)
    @sources.each do |src|
       @makefile.install(src, @dest, { 'mode' => @mode })
    end
  end

end

# An external header file
#
class Header

  # Check if a relative header path exists by compiling a test program.
  def initialize(path, compiler)
    @path = path
    @compiler = compiler
    @exists = check_exists
  end

  # Returns true if the header file exists.
  def exists?
    @exists
  end

  # Returns preprocessor directive for inclusion in config.h
  def to_config_h
     id = @path.upcase.gsub(%r{[.-]}, '_')
     if @exists
       "#define HAVE_" + id + " 1\n"
     else
       "#undef  HAVE_" + id + "\n" 
     end
  end

  private

  def check_exists
    printf "checking for #{@path}... "
    rc = @compiler.test_compile("#include <" + @path + ">")
    puts rc ? 'yes' : 'no'
    rc
  end
     
end

# A project contains all of the information about the build.
#
class Project

  attr_accessor :installer

  require 'yaml'

  # Creates a new project
  # === Parameters
  # * _manifest_ - path to a YAML manifest
  def initialize(manifest)
    @installer = nil
    @ast = parse(manifest)
    @platform = Platform.new()
    @cc = CCompiler.new(@platform)
    @mf = Makefile.new(@platform, @ast['project'], @ast['version'].to_s)
    @header = {}
    
    # TODO-Include subprojects
    #@subproject = {}
    #@ast['subdirs'].each do |x| 
    #@subproject[x] = Project.new(subdir + x + '/config.yaml', subdir + x + '/') 
    #end

    check_headers
    make_libraries
    make_binaries
    make_scripts
    make_tests
  end

  # Create the Makefile and config.h files.
  def finalize

    # Define Makefile variables
    @mf.define_variable('CFLAGS', '=', 'todo')
    @mf.define_variable('LDFLAGS', '=', 'todo')
    @mf.define_variable('LDADD', '=', 'todo')
    @mf.define_variable('CC', '=', @cc.path)
    @mf.define_variable('STANDARD_API', '=', 'posix')
    @installer.makefile_variables.each do |k,v|
      @mf.define_variable(k, '=', v)
    end

    write_config_h
    write_makefile
  end

  private

  def parse(manifest)
    default = {
        'libraries' => [],
        'binaries' => [],
        'scripts' => [],
        'tests' => [],
        'check_header' => [],
    }
    ast = YAML.load_file(manifest)
    default.each { |k,v| ast[k] ||= v }
    ast
  end

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

  def make_scripts
    @ast['scripts'].each do |k,v|
        Script.new(k, v, @mf).build
    end
  end

  def make_tests
    return unless @ast['tests']
    deps = []
    @ast['tests'].each do |k,v|
        Binary.new(k, v, @cc, @mf).build
        deps.push k
    end
    @mf.add_target('check', deps, deps.map { |d| './' + d })
  end

  def write_makefile
    ofile = 'Makefile'
    puts 'writing ' + ofile
    f = File.open(ofile, 'w')
    f.print "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n"
    f.print @mf.to_s
    f.close
  end

  def write_config_h
    ofile = 'config.h'
    puts 'Creating ' + ofile
    f = File.open(ofile, 'w')
    f.print "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n"
    @header.each { |k,v| f.print v.to_config_h }
    f.close
  end

end

#######################################################################
#
#                               MAIN()
#

#TODO:
#require 'logger'
#File.unlink('config.log')
#log = Logger.new('config.log')

m = Makeconf.new()
m.configure
m.finalize
