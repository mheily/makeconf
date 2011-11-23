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
    @installer = Installer.new()
    @proj = Project.new(manifest, @installer)
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

  # Examine the operating environment and set configuration options
  def configure
     parse_options
     @installer.configure
     @proj.configure
     @installer.package = @proj.name
  end

  # Write all output files
  def finalize
    @proj.finalize
  end

end

#
# Abstraction for platform-specific system commands and variables
# This class only contains static methods.
#
class Platform

  attr_reader :host_os, :target_os

  require 'rbconfig'

  # TODO: allow target_os to be overridden for cross-compiling

  @@host_os = Config::CONFIG['host_os']
  @@target_os = @@host_os

  # Returns true or false depending on if the target is MS Windows
  def Platform.is_windows?
    @@target_os =~ /mswin|mingw/
  end

  # Returns true or false depending on if the target is Solaris
  def Platform.is_solaris?
    @@target_os =~ /^solaris/
  end

  # Returns the name of the operating system vendor
  def Platform.vendor
    return 'Fedora' if File.exists?('/etc/fedora-release')
    return 'Red Hat' if File.exists?('/etc/redhat-release')
    return 'Debian' if File.exists?('/etc/debian_version')
    return 'Unknown' 
  end
  
  # Returns the native word size
  def Platform.word_size
    if @@host_os =~ /^solaris/
      `/usr/bin/isainfo -b`.to_i
    elsif @@host_os =~ /^linux/
      if `/usr/bin/file /bin/bash` =~ /32-bit/
        return 32
      else
        return 64
      end
    else
      throw 'Unknown word size'
    end
  end

  def Platform.archiver(archive,members)
    if is_windows? && ! ENV['MSYSTEM']
      'lib.exe ' + members.join(' ') + ' /OUT:' + archive
    else
      # TODO: add '/usr/bin/strip --strip-unneeded' + archive
      'ar rs ' + archive + ' ' + members.join(' ')
   end
  end

  # Create a directory and all of it's components
  def Platform.mkdir(path)
    if path.kind_of?(Array)
        path = path.join(' ')
    end
    throw 'invalid path' if path.nil? or path == ''
    if is_windows?
       throw 'FIXME'
    else
       "umask 22 ; mkdir -p #{path}"
    end
  end

  # Remove a regular file
  def Platform.rm(path)
    if path.kind_of?(Array)
        path = path.join(' ')
    end
    if is_windows? && ! ENV['MSYSTEM']
      return 'del /F ' + path
    else
      return 'rm -f ' + path
    end
  end

  # Remove a directory along with all of it's contents
  def Platform.rmdir(path)
    is_windows? ? "rmdir /S /Q #{path}" : "rm -rf #{path}"
  end

  def Platform.cp(src,dst)
    if src.kind_of?(Array)
      src = src.join(' ')
    end

    if is_windows? && ! ENV['MSYSTEM']
      return "copy #{src} #{dst}"
    else
      return "cp #{src} #{dst}"
    end
  end

  # Send all output to /dev/null or it's equivalent
  def Platform.dev_null
    if is_windows? && ! ENV['MSYSTEM'] 
      ' >NUL 2>NUL' 
    else
      ' >/dev/null 2>&1'
    end
  end

  # The extension used for executable files 
  def Platform.executable_extension
    is_windows? ? '.exe' : ''
  end

  # The extension used for intermediate object files 
  def Platform.object_extension
    is_windows? ? '.obj' : '.o'
  end

  # The extension used for static libraries
  def Platform.static_library_extension
    is_windows? ? '.lib' : '.a'
  end

  # The extension used for shared libraries
  def Platform.shared_library_extension(abi_major,abi_minor)
    is_windows? ? '.dll' : '.so.' + abi_major + '.' + abi_minor
  end

  # Emulate the which(1) command
  def Platform.which(command)
    return nil if is_windows?      # FIXME: STUB
    ENV['PATH'].split(':').each do |prefix|
      path = prefix + '/' + command
      return command if File.executable?(path)
    end
    nil
  end

end

# An installer copies files from the current directory to an OS-wide location
class Installer

  attr_reader :dir
  attr_accessor :package

  def initialize()
    @items = []
    @package = nil  # provided later by the user
    @path = nil

    # Set default installation paths
    @dir = {
        'prefix' => '/usr/local',
        'exec-prefix' => '$(PREFIX)',

        'bindir' => '$(EPREFIX)/bin',
        'datarootdir' => '$(PREFIX)/share',
        'datadir' => '$(DATAROOTDIR)',
        'docdir' => '$(DATAROOTDIR)/doc/$(PACKAGE)',
        'includedir' => '$(PREFIX)/include',
        'infodir' => '$(DATAROOTDIR)/info',
        'libdir' => '$(EPREFIX)/lib',
        'libexecdir' => '$(EPREFIX)/libexec',
        'localedir' => '$(DATAROOTDIR)/locale',
        'localstatedir' => '$(PREFIX)/var',
        'mandir' => '$(DATAROOTDIR)/man',
        'oldincludedir' => '/usr/include',
        'sbindir' => '$(EPREFIX)/sbin',
        'sysconfdir' => '$(PREFIX)/etc',
        'sharedstatedir' => '$(PREFIX)/com',
        
        #TODO: document this
        #DEPRECATED: htmldir, dvidir, pdfdir, psdir
    }
 
  end

  # Examine the operating environment and set configuration options
  def configure
    printf 'checking for a BSD-compatible install.. '
    if Platform.is_windows?
       puts 'not found'
    else
       @path = search() or throw 'No installer found'
       printf @path + "\n"
    end
  end

  # Parse command line options.
  # Should only be called from Makeconf.parse_options()
  def parse_options(opts)
    opts.separator ""
    opts.separator "Installation options:"

    @dir.sort.each do |k, v|
       opts.on('--' + k + ' [DIRECTORY]', "TODO describe this [#{v}]") do |arg|
          @dir[k] = arg
       end
    end

  end

  # Register a file to be copied during the 'make install' phase.
  def install(src,dst,mode = nil)
  end

  # Return a hash of variables to be included in a Makefile
  def makefile_variables
    res = { 
        'PACKAGE' => @package,
        'PKGINCLUDEDIR' => '$(INCLUDEDIR)/$(PACKAGE)',
        'PKGDATADIR' => '$(DATADIR)/$(PACKAGE)',
        'PKGLIBDIR' => '$(LIBDIR)/$(PACKAGE)',
    }
    res['INSTALL'] = @path unless @path.nil?
    @dir.each do |k,v|
      k = (k == 'exec-prefix') ? 'EPREFIX' : k.upcase
      res[k] = v
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

# A packager produces a package in the preferred OS format (e.g. RPM, DEB)
class Packager

  #attr_accessor :package

  def initialize(project)
    @project = project
  end

  def finalize
    make_rpm_spec
  end

  # Generate the rules for 'make package'
  def to_make
     {
       'package' =>
          [
	  	['clean', '$(DISTFILE)'],
     		['rm -rf rpm *.rpm',
                 'mkdir -p rpm/BUILD rpm/RPMS rpm/SOURCES rpm/SPECS rpm/SRPMS',
                 'mkdir -p rpm/RPMS/i386 rpm/RPMS/x86_64',
		 'cp $(DISTFILE) rpm/SOURCES',
  		 'rpmbuild --define "_topdir ./rpm" -bs rpm.spec',
  	   	 'mv ./rpm/SRPMS/* .',
      		 'rm -rf rpm',
     		],
     	],
     }
  end

  # Generate an RPM spec file
  def make_rpm_spec
    puts 'writing rpm.spec'
    f = File.open('rpm.spec', 'w')
    f.puts <<EOF
# DO NOT EDIT -- automatically generated by ./configure
Name:       #{@project.name}
Summary:    PKG_SUMMARY
Version:    #{@project.ast['version']}
Release:    1
License:    #{@project.ast['license']}
Vendor:     #{@project.ast['author']}
Group:      System Environment/Libraries
Source0:    %{name}-%version.tar.gz

%description
PKG_DESCRIPTION

%package devel
Summary: Header files, libraries and development documentation for %{name}
Group: Development/Libraries
Requires: %{name} = %{version}-%{release}

%description devel
This package contains the header files, static libraries and development
documentation for %{name}. If you like to develop programs using %{name},
you will need to install %{name}-devel.

%prep
%setup -q -n PROGRAM-VERSION

%build
./configure --prefix=/usr
make

%install
make DESTDIR=%{buildroot} install

%clean
[ %{buildroot} != "/" ] && rm -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root)

/usr/lib/*.so.*

%files devel
%defattr(-,root,root)

/usr/lib/*.so
/usr/include/*
/usr/share/man/man3/*

%changelog
* Thu Jan 01 2011 Some Person <nobody@nobody.invalid> - #{@project.ast['version']}-1
- automatically generated spec file
EOF
  f.close()
  end
end

# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  def initialize
    @flags = []
  end

  # Sets the ELF soname to the specified string
  def soname(s)
    unless Platform.is_windows?
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
  attr_accessor :is_library, :is_shared, :is_makefile, :sources, :ld

  def initialize(language, extension, ldflags = '', cflags = '')
    @language = language
    @extension = extension
    @cflags = cflags
    @extra_cflags = ''
    @ldflags = ldflags
    @ldadd = ''
    @output = nil
    @is_library = false
    @is_shared = false
    @is_makefile = false        # if true, the output will be customized for use in a Makefile
    @ld = Linker.new()
  end

  def clone
    # does this deep copy the linker?
    Marshal.load(Marshal.dump(self))
  end

  # Search for a suitable compiler
  def search(compilers)
    res = nil
    printf "checking for a " + @language + " compiler.. "
    if ENV['CC']
      res = ENV['CC']
    else
      compilers.each do |command|
         if Platform.which(command)
           res = command
           break
         end
      end
    end

    # FIXME: kludge for Windows, breaks mingw
    if Platform.is_windows?
        res = 'cl.exe'
    end

    throw 'No compiler found' if res.nil? || res == ''

    if Platform.is_windows? && res.match(/cl.exe/i)
        help = ' /? <NUL'
    else
        help = ' --help'
    end
    
    # Verify the command can be executed
    cmd = res + help + Platform.dev_null
    unless system(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    @path = res
  end

  # Add additional user-defined compiler flags
  def append_cflags(s)
    @extra_cflags += ' ' + s
  end

  # Add additional user-defined link-time objects
  def append_ldflags(s)
    @ldflags += ' ' + s
  end

  # Add additional user-defined link-time objects
  def append_ldadd(s)
    @ldadd += ' ' + s
  end

  # Return the intermediate object files for each source file
  def objs
    o = Platform.object_extension
    @sources.map { |s| s.sub(/.c$/, ((!@is_library or @is_shared) ? o : '-static' + o)) }
  end

  # Return the complete command line to compile an object
  def command(output)
    throw 'Invalid linker' unless @ld.is_a?(Linker)

    cflags = @cflags + @extra_cflags
    cflags += ' -c'
    cflags += ' -fpic -shared' if @is_library and @is_shared

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
      cflags.gsub!(/ -fpic /, ' ')
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
    # We are also expected to pass additional variables
    if @is_makefile
      inputs = ''
      cflags += ' $(CFLAGS)'
    end
       
    [ @path, cflags, inputs, @ldadd ].join(' ')
  end

  # Compile a test program
  def test_compile(code)

    # Write the code to a temporary source file
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
    objfile = f.path + '.out'

    # Run the compiler
    cc = self.clone
    cc.sources = f.path
    cmd = command(objfile) + Platform.dev_null
    rc = system cmd

    File.unlink(objfile) if rc
    return rc
  end

  # Return a hash containing Makefile rules and targets
  def to_make(output)
    res = {}

    # Generate the targets and rules for each translation unit
    objs().sort.each do |d| 
      src = d.sub(/#{Platform.object_extension}$/, '.c')
      x = Platform.is_windows? ? ' /Fo' + d : ' -o ' + d
      cmd = command(d)
      res[d] = [src, cmd + x + ' ' + src]
    end

    # Generate the targets and rules for the link stage
    cflags = [ "-o #{output}" ]
    cflags.push('-shared') if @is_library and @is_shared
    cmd = ['$(CC)', cflags, ldflags, '$(LDFLAGS)', objs().sort, @ldadd, '$(LDADD)'].flatten.join(' ')
    res[output] = [objs().sort, cmd]

    return res
  end

end

class CCompiler < Compiler

  attr_accessor :output_type

  def initialize
    @output_type = nil
    super('C', '.c')
    search(['cc', 'gcc', 'clang', 'cl.exe'])

    # GCC on Solaris produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       @cflags += ' -m64'
       @ldflags += '-m64'
    end
  end

end

# A target is a section in a Makefile
class Target

  def initialize(objs, deps = [], rules = [])
      deps = [ deps ] unless deps.kind_of?(Array)
      rules = [ rules ] unless rules.kind_of?(Array)
      @objs = objs
      @deps = deps
      @rules = rules
      @dirs_to_create = []      # directories to create
      @files_to_copy = {}       # files to be copied
  end

  # Ensure that a directory is created before any rules are evaluated
  def mkdir(path)
    @dirs_to_create.push(path) unless @dirs_to_create.include?(path)
  end

  # Copy a file to a directory. This is more efficient than calling cp(1)
  # for each file.
  def cp(src,dst)
    @files_to_copy[dst] ||= []
    @files_to_copy[dst].push(src)
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

  # Return the string representation of the target
  def to_s
    res = "\n" + @objs + ':'
    res += ' ' + @deps.join(' ') if @deps
    res += "\n"
    unless @dirs_to_create.empty?
       res += "\t" + Platform.mkdir(@dirs_to_create) + "\n"
    end
    @files_to_copy.each do |k,v|
       res += "\t" + Platform.cp(v, k) + "\n"
    end
    @rules.each { |r| res += "\t" + r + "\n" }
    res
  end

end

# A Makefile is a collection of targets and rules used to build software.
#
class Makefile
  
  # Object constructor.
  # === Parameters
  # * _installer_ - The installer to use
  # * _project_ - The name of the project
  # * _version_ - The version number of the project
  #  
  def initialize(installer, project, version)
    @installer = installer
    @project = project
    @version = version
    @vars = {}
    @targets = {}
    @mkdir_list = []   # all directories that have been created so far

    parse_environment

    %w[all clean distclean install uninstall distdir].each do |x|
        @targets[x] = Target.new(objs = x)
    end

    add_target('dist', ['clean', '$(DISTFILE)'], [])
    add_target('check', [], [])

    # Prepare the destination tree for 'make install'
    @targets['install'].add_rule('test -e $(DESTDIR)')

    # Distribute some standard files with 'make distdir'
    ['config.yaml', 'configure'].each { |f| distribute(f) }

    # Distribute makeconf.rb
    if File.exists?('makeconf.rb')
        distribute('makeconf.rb')
    elsif File.exists?('makeconf/makeconf.rb')
        distribute('makeconf/makeconf.rb')
    else
        throw 'Unable to locate makeconf.rb'
    end
  end

  def define_variable(lval,op,rval)
    throw "invalid arguments" if lval.nil? or op.nil? 
    throw "variable `#{lval}' is undefined" if rval.nil?
    @vars[lval] = [ op, rval ]
  end

  # Add one or more targets to a Makefile.
  # === Parameters
  # * _h_ - a hash where each key is a target and each value is an array of rules
  #
  def merge(h)
    throw 'invalid argument' unless h.is_a?(Hash)
    h.each do |k,v|
       throw 'invalid entry' unless v.is_a?(Array)
       add_target(k, v[0], v[1])
    end
  end

  def add_target(object,depends,rules)
    @targets[object] = Target.new(object,depends,rules)
  end

  def add_rule(target, rule)
    @targets[target].add_rule(rule)
  end

  # Add a file to the tarball during 'make dist'
  def distribute(path)
    # FIXME: support Windows backslashery
    if path =~ /\//
       dst = '$(distdir)/' + File.dirname(path)
       @targets['distdir'].mkdir(dst)
       @targets['distdir'].cp(path, dst)
    else
       @targets['distdir'].cp(path, '$(distdir)')
    end
  end

  # Add a file to be removed during 'make clean'
  def clean(path)
    @targets['clean'].add_rule(Platform.rm(path))
  end

  def add_dependency(target,depends)
    @targets[target].add_dependency(depends)
  end

  # Add a file to be installed during 'make install'
  def install(src,dst,opt = {})
    rename = opt.has_key?('rename') ? opt['rename'] : false
    mode = opt.has_key?('mode') ? opt['mode'] : nil
    mkdir = opt.has_key?('mkdir') ? opt['mkdir'] : true

    # Determine the default mode based on the execute bit
    if mode.nil?
      mode = File.executable?(src) ? '755' : '644'
    end

    # Automatically create the destination directory, if needed
    if mkdir and not @mkdir_list.include?(dst)
       add_rule('install', "test -e $(DESTDIR)#{dst} || $(INSTALL) -d -m 755 $(DESTDIR)#{dst}")
       @mkdir_list.push(dst)
    end

    add_rule('install', "$(INSTALL) -m #{mode} #{src} $(DESTDIR)#{dst}")
    add_rule('uninstall', Platform.rm("$(DESTDIR)#{dst}/#{File.basename(src)}"))

    # FIXME: broken
#   if (rename) 
#      add_rule('uninstall', Platform.rm('$(DESTDIR)' + dst))
#    else 
#      raise "FIXME"
##add_rule('uninstall', Platform.rm('$(DESTDIR)' + $dst + '/' . basename($src)));
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
    # XXX-FIXME this should come from the Project
    distfile = @project + '-' + @version + '.tar.gz'
    tg = Target.new(distfile)
    tg.add_rule(Platform.rmdir(distdir))
    tg.add_rule("mkdir " + distdir)
    tg.add_rule('$(MAKE) distdir distdir=' + distdir)
    if Platform.is_windows? 
       require 'zip/zip'
# FIXME - Not implemented yet

    else
       tg.add_rule("rm -rf #{distdir}.tar #{distdir}.tar.gz")
       tg.add_rule("tar cf #{distdir}.tar #{distdir}")
       tg.add_rule("gzip #{distdir}.tar")
       tg.add_rule("rm -rf #{distdir}")
       clean("#{distdir}.tar.gz")
    end
    @targets[distfile] = tg
  end

  def parse_environment
     # TODO
  end

end

# A buildable object like a library or executable
class Buildable

  attr_accessor :installable, :distributable

  def initialize(id, ast, compiler, makefile)
    @id = id
    @ast = ast
    @makefile = makefile
    @installable = true
    @distributable = true
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

    @compiler = compiler.clone
    @compiler.append_cflags(@cflags)
    @compiler.append_ldflags(@ldflags)
    @compiler.append_ldadd(@ldadd)
  end

  def build
    @makefile.clean(@output)
    @makefile.distribute(@sources) if @distributable
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
    }
    default.each do |k,v| 
      v = ast[k] unless ast[k].nil?
      v = v.to_s if default[k].is_a?(String)
      instance_variable_set('@' + k, v)
    end
  end

  def build
    build_static_library
    build_shared_library
    super()
  end

  private

  def build_static_library
    libfile = @id + Platform.static_library_extension
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = false
    cc.is_makefile = true
    cc.sources = @sources
    cc.append_cflags(@cflags)
    cmd = cc.command(libfile)
    deps = cc.objs.sort
    deps.each do |d| 
      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
      output = Platform.is_windows? ? ' /Fo' + d : ' -o ' + d
      @makefile.add_target(d, src, cmd + output + ' ' + src) 
    end
    @makefile.add_target(libfile, deps, Platform.archiver(libfile, deps))
    @makefile.clean(cc.objs)
    @output.push libfile
  end

  def build_shared_library
    libfile = @id + Platform.shared_library_extension(@abi_major,@abi_minor)
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = true
    cc.is_makefile = true
    cc.sources = @sources
    cc.append_cflags(@cflags)

    deps = cc.objs.sort

    if Platform.is_windows?
      @makefile.add_target(libfile, deps, 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
      # FIXME: shouldn't we use cmd to build the dll ??
    else
      cc.ld.export_dynamic
      cc.ld.soname(@id + '.' + @abi_major)
      @makefile.merge(cc.to_make(libfile))
    end 
    @makefile.install(libfile, '$(LIBDIR)')
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
    binfile = @id + Platform.executable_extension
    cc = @compiler.clone
    cc.is_library = false
    cc.is_makefile = true
    cc.sources = @sources

#XXX-BROKEN cc.add_targets(@makefile)

    @makefile.merge(cc.to_make(binfile))

    @makefile.clean(cc.objs)
    @makefile.install(binfile, '$(BINDIR)', { 'mode' => '755' }) \
        if @installable
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

  attr_reader :name, :distfile, :ast

  require 'yaml'

  # Creates a new project
  # === Parameters
  # * _manifest_ - path to a YAML manifest
  def initialize(manifest,installer)
    @installer = installer
    @packager = Packager.new(self)
    @ast = parse(manifest)
    @name = @ast['project']
    @distfile = @ast['project'] + '-' + @ast['version'] + '.tar.gz'
    @mf = Makefile.new(@installer, @name, @ast['version'].to_s)
    @header = {}
    
    # TODO-Include subprojects
    #@subproject = {}
    #@ast['subdirs'].each do |x| 
    #@subproject[x] = Project.new(subdir + x + '/config.yaml', subdir + x + '/') 
    #end

  end

  # Examine the operating environment and set configuration options
  def configure
    @cc = CCompiler.new()
    check_headers
    make_libraries
    make_binaries
    make_scripts
    make_extra_dist
    make_installable(@ast['headers'], '$(PKGINCLUDEDIR)')
    make_installable(@ast['data'], '$(PKGDATADIR)')
    make_installable(@ast['manpages'], '$(MANDIR)') #FIXME: Needs a subdir
    make_tests
  end

  # Create the Makefile and config.h files.
  def finalize

    # Pass environment variables
    %w[CFLAGS LDFLAGS LDADD].each do |k|
       v = ENV[k].nil? ? '' : ENV[k]
       @mf.define_variable(k, '=', v)
    end

    # Define Makefile variables
    @mf.define_variable('CC', '=', @cc.path)
    @mf.define_variable('STANDARD_API', '=', 'posix')
    @mf.define_variable('DISTFILE', '=', @distfile)
    @installer.makefile_variables.each do |k,v|
      @mf.define_variable(k, '=', v)
    end

    write_config_h
    @packager.finalize
    @mf.merge(@packager.to_make)
    write_makefile
  end

  private

  def parse(manifest)
    default = {
        'project' => 'myproject',
        'version' => '0.1',
        'author' => 'Unknown Author <nobody@nowhere.invalid>',
        'license' => 'Unknown License',
        'summary' => 'Unknown Project Summary',

        'binaries' => [],
        'data' => [],
        'headers' => [],
        'libraries' => [],
        'manpages' => [],
        'scripts' => [],
        'tests' => [],
        'extra_dist' => [],

        'check_header' => [],
    }
    ast = YAML.load_file(manifest)
    default.each do |k,v| 
        if ast.has_key?(k)
          if ast[k].is_a?(Float) and v.is_a?(String)
            ast[k] = ast[k].to_i.to_s
          elsif ast[k].is_a?(Integer) and v.is_a?(String)
            ast[k] = ast[k].to_s
          end
        else
          ast[k] = v
        end
    end
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

  def make_extra_dist
    @ast['extra_dist'].each do |k|
      Dir.glob(k).each { |f| @mf.distribute(f) }
    end
  end

  # Add targets for distributing and installing ordinary non-compiled files,
  # such as data or manpages.
  #
  def make_installable(ast,default_dest)
    h = {}
    if ast.is_a?(Array)
      ast.each do |e|
         h[e] = { 'dest' => default_dest }
      end
    elsif ast.is_a?(Hash)
       h = ast
    else
       throw 'Unsupport AST type'
    end

    h.each do |k,v|
        if v.is_a?(String)
          v = { 'dest' => v }
        end
        Dir.glob(k).each do |f|
          @mf.distribute(f)
          @mf.install(f, v['dest'], v)
       end
    end
  end

  def make_tests
    return unless @ast['tests']
    deps = []
    @ast['tests'].each do |k,v|
        k = 'test-' + k
        b = Binary.new(k, v, @cc, @mf)
        b.installable = false
        b.distributable = false
        b.build
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
