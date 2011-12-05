# A project contains all of the information about the build.
#
class Project

  attr_reader :id, :version, :summary, :description, :license, :author, :distfile
  attr_accessor :makefile, :installer, :packager

  require 'yaml'

  # Creates a new project
  def initialize(h)
    @id = h[:id]
    @version = h[:version] || '0.1'
    @summary = h[:summary] || 'Undefined project summary'
    @description = h[:description] || 'Undefined project description'
    @license = h[:license] || 'Unknown license'
    @author = h[:author] || 'Unknown author'
    @header = {}        # Hash of system header availablity
    @build = []         # List of items to build
    @distribute = []    # List of items to distribute
    @install = []       # List of items to install
    @test = []          # List of unit tests
    @cc = CCompiler.new()
    @packager = Packager.new(self)

    # Provided by the parent Makeconf object
    @installer = nil
    @makefile = nil

    [:id, :version].each do |k|
      raise ArgumentError.new("Missing argument: #{k}") \
          unless h.has_key? k
    end

    [:manpages, :headers, :libraries, :tests].each do |k|
       h[k] = [] unless h.has_key? k
    end

    h[:manpages].each { |x| manpage(x) } 
    h[:headers].each { |x| header(x) }   
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
  end

  # Examine the operating environment and set configuration options
  def configure

    # Test for the existence of each referenced system header
    system_headers = []
    @build.each do |x| 
      system_headers.push x.system_headers
    end

    system_headers.flatten.sort.uniq.each do |header|
      printf "checking for #{header}.. "
      @header[header] = @cc.check_header(header)
      puts @header[header] ? 'yes' : 'no'
    end

#    make_installable(@ast['data'], '$(PKGDATADIR)')
#    make_installable(@ast['manpages'], '$(MANDIR)') #FIXME: Needs a subdir
  end

  # Create the Makefile and config.h files.
  def finalize

    @makefile.toplevel_init  #FIXME bad place for this

    # Pass environment variables
    %w[CFLAGS LDFLAGS LDADD].each do |k|
       v = ENV[k].nil? ? '' : ENV[k]
       @makefile.define_variable(k, '=', v)
    end

    # Define Makefile variables
#DEADWOOD: prevents mixing compilers in a multi-project environment: @makefile.define_variable('CC', '=', @cc.path)
    @makefile.define_variable('STANDARD_API', '=', 'posix')
    distfile = @id + '-' + @version + '.tar.gz'
    @makefile.define_variable('DISTFILE', '=', distfile)

    # Add extra_dist items to the Makefile
    @distribute.each { |f| @makefile.distribute(f) }

    write_config_h
    @packager.finalize
    @makefile.merge!(@packager.makefile)
    @makefile.make_dist(@id, @version)

    # Build each buildable object
    @build.each do |x| 
      x.finalize
      @makefile.merge! @cc.build(x)
    end

    # Add installable items
    @install.each { |x| @installer.install(x) }
    @makefile.merge! @installer.to_make

    # Add unit tests
    @test.each do |x| 
      @makefile.add_dependency('check', x.id)
      @makefile.add_rule('check', './' + x.id)
    end

    write_makefile
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
      @extra_dist.push Dir.glob(x)
      distribute x
    end
  end

  # Add item(s) to distribute in the source tarball
  def distribute(*arg)
    arg.each do |x|
      @extra_dist.push Dir.glob(x)
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
        x.cflags.push('-g', '-O0')

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

  def write_makefile
    ofile = 'Makefile'
    puts 'writing ' + ofile
    f = File.open(ofile, 'w')
    f.print "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n"
    f.print @makefile.to_s
    f.close
  end

  def write_config_h
    ofile = 'config.h'
    puts 'Creating ' + ofile
    f = File.open(ofile, 'w')
    f.print "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n"
    @header.keys.sort.each do |k|
      v = @header[k]
      id = k.upcase.gsub(%r{[/.-]}, '_')
      if v == true
        f.printf "#define HAVE_" + id + " 1\n"
      else
        f.printf "#undef  HAVE_" + id + "\n" 
      end
    end
    f.close
  end

end
