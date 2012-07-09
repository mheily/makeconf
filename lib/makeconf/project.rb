# A project contains all of the information about the build.
#
class Project
 
  require 'yaml'
  require 'net/http'

  attr_accessor :id, :version, :summary, :description, 
        :author, :license, :license_file, :config_h

  # KLUDGE: remove these if possible                
  attr_accessor :makefile, :installer, :packager

  # Creates a new project
  def initialize(manifest = 'config.yaml')
    @id = 'myproject'
    @version = '0.1'
    @summary = 'Undefined project summary'
    @description = 'Undefined project description'
    @license = 'Unknown license'
    @author = 'Unknown author'
    @config_h = 'config.h'
    @header = {}        # Hash of system header availablity
    @build = []         # List of items to build
    @distribute = []    # List of items to distribute
    @install = []       # List of items to install
    @target = []        # List of additional Makefile targets
    @test = []          # List of unit tests
    @decls = {}         # List of declarations discovered via check_decl()
    @funcs = {}         # List of functions discovered via check_func()
    @packager = Packager.new(self)

    # Provided by the parent Makeconf object
    @installer = nil
    @makefile = nil

    @manifest = YAML.load_file(manifest)

    # Determine the path to the license file
    @license_file = @manifest['license_file']
    if @license_file.nil?
      %w{COPYING LICENSE}.each do |p|
        if File.exists?(p)
            @license_file = p
            break
        end
      end
    end

#    # Initialize missing variables to be empty Arrays 
#    [:manpages, :headers, :libraries, :tests, :check_decls, :check_funcs,
#     :extra_dist, :targets, :binaries].each do |k|
#       h[k] = [] unless h.has_key? k
#       h[k] = [ h[k] ] if h[k].kind_of?(String)
#    end
#    h[:scripts] = {} unless h.has_key?(:scripts)

     # Generate a hash containing all the different element types
     #items = {}
     #%w{manpage header library binary test check_decl check_func extra_dist targets}.each do |k|
     #  items[k] = xml.elements[k] || []
     #end

     @manifest.each do |key,val|
        #p "key=#{key} val=#{val}"
       case key
       when 'project'
         @id = val
       when 'version'
         @version = val.to_s
       when 'binary', 'binaries' 
         val.each do |id, e|
           id += Platform.executable_extension
           @build.push Binary.new(id).parse(e)
         end
       when 'library', 'libraries'
         val.each do |id, e|
           build SharedLibrary.new(id).parse(e)
           build StaticLibrary.new(id).parse(e)
         end
       when 'tests'
         val.each do |id, e|
           test Binary.new(id).parse(e)
         end
       when 'manpage'
          manpage(val)  
       when 'header'
          header(val)  
       when 'extra_dist'
          distribute val 
       when 'targets'
          target val
       when 'script', 'check_decl', 'check_func'
          throw 'FIXME'
            #items['script'].each { |k,v| script(k,v) }
            #items['check_decl'].each { |id,decl| check_decl(id,decl) }
#items['check_func'].each { |f| check_func(f) }
       else
          throw "Unrecognized entry in manifest -- #{key}: #{val}"
       end
     end

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
    @build.each { |x| makefile.merge!(@cc.build(x)) if x.enable }
    makefile.merge! @installer.to_make

    # Add custom targets
    @target.each { |t| makefile.add_target t }

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

  # Add a script to be installed
  def script(id, opt = {})
    throw ArgumentError, 'bad options' unless opt.kind_of? Hash
    @install.push({ 
        :sources => opt[:sources],
        :dest => (opt[:dest].nil? ? "$(BINDIR)" : opt[:dest]),
        :rename => opt[:rename],
        :mode => '0755',
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

  # Add an additional Makefile target
  def target(t)
    throw ArgumentError.new('Invalid data type') unless t.kind_of?(Target) 
    @target.push t
  end

#XXX fixme -- testing
  def mount(uri,subdir)
    x = Net::HTTP.get(URI(uri))
    puts x.length
  end

end
