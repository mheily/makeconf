# A project contains all of the information about the build.
#
class Project
 
  require 'net/http'

  attr_accessor :id, :version, :summary, :description, 
        :author, :license, :license_file, :config_h

  # KLUDGE: remove these if possible                
  attr_accessor :makefile, :installer, :packager


  require 'yaml'

  # Creates a new project
  def initialize(h = {})
    @id = h[:id] || 'myproject'
    @version = h[:version] || '0.1'
    @summary = h[:summary] || 'Undefined project summary'
    @description = h[:description] || 'Undefined project description'
    @license = h[:license] || 'Unknown license'
    @author = h[:author] || 'Unknown author'
    @config_h = h[:config_h] || 'config.h'
    @header = {}        # Hash of system header availablity
    @build = []         # List of items to build
    @distribute = []    # List of items to distribute
    @install = []       # List of items to install
    @test = []          # List of unit tests
    @decls = {}         # List of declarations discovered via check_decl()
    @funcs = {}         # List of functions discovered via check_func()
    @packager = Packager.new(self)

    # Provided by the parent Makeconf object
    @installer = nil
    @makefile = nil

    # Determine the path to the license file
    @license_file = h[:license_file]
    if @license_file.nil?
      %w{COPYING LICENSE}.each do |p|
        if File.exists?(p)
            @license_file = p
            break
        end
      end
    end

    [:manpages, :headers, :libraries, :tests, :check_decls, :check_funcs,
     :extra_dist].each do |k|
       h[k] = [] unless h.has_key? k
       h[k] = [ h[k] ] if h[k].kind_of?(String)
    end

    h[:manpages].each { |x| manpage(x) } 
    h[:headers].each { |x| header(x) }   
    h[:libraries].each do |id,buildable| 
       buildable[:id] = id
       build SharedLibrary.new(buildable)
       build StaticLibrary.new(buildable)
    end
    h[:tests].each do |id,buildable| 
       buildable[:id] = id
       test Binary.new(buildable)
    end
    h[:check_decls].each { |id,decl| check_decl(id,decl) }
    h[:check_funcs].each { |f| check_func(f) }
    h[:extra_dist].each { |f| distribute(f) }
    yield self if block_given?
  end

  # Examine the operating environment and set configuration options
  def configure

    @cc ||= CCompiler.new() #FIXME: stop this

    # Build a list of local headers
    local_headers = []
    @build.each do |x| 
      local_headers.concat @cc.makedepends(x)
    end
    local_headers.sort!.uniq!

    # Test for the existence of each referenced system header
    sysdeps.each do |header|
      printf "checking for #{header}... "
      @header[header] = @cc.check_header(header)
      puts @header[header] ? 'yes' : 'no'
    end

#    make_installable(@ast['data'], '$(PKGDATADIR)')
#    make_installable(@ast['manpages'], '$(MANDIR)') #FIXME: Needs a subdir
  end

  # Return the Makefile for the project
  # This should only be done after finalize() has been called.
  def to_make
    makefile = Makefile.new

    makefile.add_dependency('dist', distfile)
    makefile.distclean(distfile)
    makefile.distclean(@config_h)
    makefile.merge!(@packager.makefile)
    makefile.make_dist(@id, @version)
    @distribute.each { |f| @makefile.distribute f }
    @build.each { |x| makefile.merge! @cc.build(x) }
    makefile.merge! @installer.to_make

    # Add unit tests
    @test.each do |x| 
      makefile.add_dependency('check', x.id)
      makefile.add_rule('check', './' + x.id)
    end

    makefile
  end

  def finalize
    @packager.finalize
    @build.each { |x| x.finalize }
    @install.each { |x| @installer.install x }
  end

  # Check if a system header declares a macro or symbol
  def check_decl(header,decl)
      throw ArgumentError unless header.kind_of? String
      decl = [ decl ] if decl.kind_of? String
      throw ArgumentError unless decl.kind_of? Array

       @cc ||= CCompiler.new() #FIXME: stop this

      decl.each do |x|
        next if @decls.has_key? x
        printf "checking whether #{x} is declared... "
        @decls[x] = @cc.test_compile "#define _GNU_SOURCE\n#include <#{header}>\nint main() { #{x}; }"
        puts @decls[x] ? 'yes' : 'no'
      end
  end

  # Check if a function is available in the standard C library
  # TODO: probably should add :ldadd when checking..
  def check_func(func)
      func = [ func ] if func.kind_of? String
      throw ArgumentError unless func.kind_of? Array

       @cc ||= CCompiler.new() #FIXME: stop this
      func.each do |x|
        next if @funcs.has_key? x
        printf "checking for #{x}... "
        @funcs[x] = @cc.test_link "void *#{x}();\nint main() { void *p;\np = &#{x}; }"
        puts @funcs[x] ? 'yes' : 'no'
      end
  end

  # Add item(s) to build
  def build(*arg)
    arg.each do |x|
      throw ArgumentError.new('Invalid argument') unless x.kind_of? Buildable

      if x.kind_of?(SharedLibrary) or x.kind_of?(StaticLibrary)
        dest = '$(LIBDIR)'
      else
        dest = '$(BINDIR)'
      end

      @build.push x
      @install.push({ 
        :sources => x.output,
        :dest => dest,
        :mode => '0755',
        })
    end
  end

  # Add item(s) to install
  def install(*arg)
    arg.each do |x|
      # FIXME: shouldn't something be installed now?
      @distribute.push Dir.glob(x)
    end
  end

  # Add item(s) to distribute in the source tarball
  def distribute(*arg)
    arg.each do |x|
      @distribute.push Dir.glob(x)
    end
  end

  # Add a C/C++ header file to be installed
  def header(path, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    @install.push({ 
        :sources => path,
        :dest => (opt[:dest].nil? ? '$(INCLUDEDIR)' : opt[:dest]),
        :mode => '0644',
        })
  end

  # Add a manpage file to be installed
  def manpage(path, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    section = path.gsub(/.*\./, '')
    @install.push({ 
        :sources => path,
        :dest => (opt[:dest].nil? ? "$(MANDIR)/man#{section}" : opt[:dest]),
        :mode => '0644',
        })
  end

  # Add item(s) to test
  def test(*arg)
    arg.each do |x|
      throw ArgumentError.new('Invalid argument') unless x.respond_to?('build')
        x.installable = false
        x.distributable = false

        # Assume that unit tests should be debuggable
        x.cflags.push('-g', '-O0') unless Platform.is_windows?

        # Assume that the unit tests may require headers and libraries
        # in the current working directory. To be sure, we should check
        # the project to see if we are actually building libraries.
        x.cflags.push('-I.')
        x.cflags.push('-I./include') if File.directory?('./include')
        x.rpath = '$$PWD'

        # FIXME: @makefile.add_target('check', deps, deps.map { |d| './' + d })
        @build.push x
        @test.push x
    end
  end

  # Return the compiler associated with the project
  def compiler(language = 'C')
    throw 'Not implemented' if language != 'C'
    throw 'Undefined compiler' if @cc.nil?
    @cc
  end

  # Return a library definition
  def library(id)
    @ast['libraries'][id]
  end

  # Return a list of all system header dependencies for all Buildable
  # objects in the project.
  def sysdeps
    res = []
    @build.each do |x|
      x.sysdep.each { |k,v| res.concat v }
    end
    res.sort.uniq
  end

  # Returns the filename of the source code distribution archive
  def distfile
    @id + '-' + @version + '.tar.gz'
  end

  # Generate the config.h header file
  def write_config_h
    ofile = @config_h
    buf = {}

    @header.keys.sort.each { |k| buf["HAVE_#{k}".upcase] = @header[k] }
    @decls.keys.sort.each { |x| buf["HAVE_DECL_#{x}".upcase] = @decls[x] }
    @funcs.keys.sort.each { |x| buf["HAVE_#{x}".upcase] = @funcs[x] }

    puts 'creating ' + ofile
    f = File.open(ofile, 'w')
    f.print "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n"
    buf.keys.sort.each do |k|
      v = buf[k]
      id = k.upcase.gsub(%r{[/.-]}, '_')
      if v == true
        f.printf "#define #{id} 1\n"
      else
        f.printf "#undef  #{id}\n" 
      end
    end
    f.close
  end

#XXX fixme -- testing
  def mount(uri,subdir)
    x = Net::HTTP.get(URI(uri))
    puts x.length
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
          @makefile.distribute(f)
          @makefile.install(f, v['dest'], v)
       end
    end
  end

end
