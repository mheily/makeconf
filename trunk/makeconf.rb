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
  require 'pp'

  require 'makeconf/buildable'
  require 'makeconf/compiler'
  require 'makeconf/installer'
  require 'makeconf/library'
  require 'makeconf/makefile'
  require 'makeconf/packager'
  require 'makeconf/platform'
  require 'makeconf/project'
  require 'makeconf/target'

  def initialize(project = nil)
    @installer = Installer.new
    @makefile = Makefile.new
    @project = {}
    @configured = false         # if true, configure() has completed
    @finalized = false          # if true, finalize() has completed
    at_exit { at_exit_handler }

    unless project.nil?
      x = Project.new(project)
      @project[x.id] = x
    end
  end

  def at_exit_handler
    configure unless @configured
    finalize unless @finalized
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
     @project.each do |id,proj|
        @installer.configure(proj)
        proj.makefile = @makefile
        proj.installer = @installer
        proj.configure
     end
     @configured = true
  end

  # Write all output files
  def finalize
     @project.each { |id,proj| proj.finalize }
     @finalized == true
  end

  #
  # Accessors
  #

  # Return a project object
  def project(id)
    @project[id]
  end

  # Search all projects for a given library
  def library(id)
    # TODO: actually use <id> when multi-project is implemented
#XXX-BROKEN
    @project.library(id)
  end

end

# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  def initialize
    @flags = []
    @cflags = [] # KLUDGE: passed to the compiler w/o the '-Wl,' prefix
  end

  def clone
    Marshal.load(Marshal.dump(self))
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

  # Override the normal search path for the dynamic linker
  def rpath=(dir)
    if Platform.is_solaris?
      @flags.push ['-R', dir]
    elsif Platform.is_linux?
      @flags.push ['-rpath', dir]
    else
      throw 'Unsupported OS'
    end
    @cflags.push ['-L', dir]
   end

  # Returns the linker flags suitable for passing to the compiler
  def to_s
     tok = []
     tok.push @cflags
     @flags.each do |f|
        if f.kind_of?(Array)
          tok.push '-Wl,-' + f[0] + ',' + f[1]
        else
          tok.push '-Wl,-' + f
        end
     end
     return ' ' + tok.join(' ')
  end

  # TODO - not used yet
  def command
    # windows: 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
    # linux: 'cc ' .... (see Compiler::)
  throw 'stub'
  end

end

# An executable binary file
class Binary < Buildable

  def initialize(h)
    super(h)
    @output_type = 'binary'
  end

  def build
    binfile = @id + Platform.executable_extension
    cc = @compiler.clone
    cc.is_library = false
    cc.sources = @sources

#XXX-BROKEN cc.add_targets(@makefile)

    @makefile.merge!(cc.to_make(binfile))

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

#DEADWOOD -- 
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

