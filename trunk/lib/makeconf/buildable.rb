# A buildable object like a library or executable
class Buildable

  attr_accessor :id, :project,
        :buildable, :installable, :distributable,
        :enable,
        :output, :output_type, :sources, :cflags, :ldadd, :rpath,
        :topdir

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    default = {
        :id => options[:id],
        :enable => true,
        :buildable => true,
        :distributable => true,
        :installable => true,
        :extension => '',
        :cflags => [],
        :ldflags => [],
        :ldadd => [],
        :rpath => '',
        :topdir => '',
        :depends => [],
    }
    default.each do |k,v| 
      instance_variable_set('@' + k.to_s, v)
    end
    @output = id
    @output_type = nil      # filled in by the derived class

    # Filled in by sources=()
    @sources = []

    # Parse options

    # FIXME- consider adding support for:
    #%w{name enable distributable installable extension
#   topdir rpath}

    log.debug "Buildable options: " + options.pretty_inspect
      
    options.each do |k,v|
      log.debug "k=#{k} v=#{v.to_s}"
      case k
      when :id
        @id = v
      when :cc
        @cc = v.clone
      when :cflags
        v = v.split(' ') if v.kind_of?(String)
        @cflags = v
      when :ldflags
        v = v.split(' ') if v.kind_of?(String)
        @ldflags = v
      when :ldadd
        @ldadd.push(v).flatten!
      when :project
        @project = v
      when :buildable
        @buildable = v
      when :sources
        v = [ v ] if v.kind_of?(String)
        @sources = v
      else
        throw "Unrecognized option -- #{k}: #{v}"
      end
    end
    log.debug "Buildable parsed as: " + self.pretty_inspect

#FIXME: move some of these to the switch statement
#    # Parse simple textual child elements
#    %w{cflags ldflags ldadd depends sources}.each do |k|
#      instance_variable_set('@' + k, yaml[k]) if yaml.has_key? k
#    end

  end

  def expand_sources(x)
    log.info "expanding [#{x.to_s}] to source file list"
    raise ArgumentError('Wrong type') unless x.is_a? Array

    # Use glob(3) to expand the list of sources
    buf = []
    x.each do |src| 
      if src =~ /\*/
        buf << Dir.glob(src)
      else
        buf.push src
      end
    end
    buf.flatten

# TODO: elsewhere
    # Ensure that all source files exist
#@sources.each do |src|
#      throw ArgumentError("#{src} does not exist") unless File.exist? src
#    end

  end

  # Return the list of intermediate object files
  def objects
     expand_sources(@sources).map { |x| x.gsub(/\.c$/, '.o') }
  end

  def library?
    @output_type == 'shared library' or @output_type == 'static library'
  end

  def library_type
    case @output_type
    when 'shared library'
    return :shared
    when 'static library'
    return :static
    else
    throw 'Not a library'
    end
  end

  def binary?
    @output_type =~ /binary/
  end

  def finalize
  end

  # Install the output file(s)
  def install(installer)
    # By default, this does nothing.
    # Derived classes are expected to override this method.
  end

  # Return a hash containing Makefile rules and targets
  # needed to build the object.
  #
  def build
    makefile = Makefile.new
    objs = []
    sources = expand_sources(@sources)

    # Don't do anything if we aren't going to be built
    return makefile unless @buildable

    # Allow ndk-build to create the object, for Android
    return makefile if SystemType.host =~ /-androideabi$/

    log.debug 'buildable = ' + self.pretty_inspect

    if sources.empty?
      pp self
      raise 'One or more source files are required' if sources.empty?
    end

    # Generate the targets and rules for each translation unit
    sources.each do |src|
      obj = src.sub(/.c$/, Platform.object_extension)
      cc = @project.cc.clone
      cc.shared_library = library? and library_type == :shared
      cc.flags = @cflags
      cc.output = obj
      cc.sources = src
      #TODO: cc.topdir = @topdir

      ld = cc.ld
      ld.flags = @ldflags
      @ldadd = [ @ldadd ] if @ldadd.kind_of?(String)
      @ldadd.each { |lib| ld.library lib }
      makefile.distribute src

      # Generate the list of dependencies. 
      # Distribute any header files that are local to the current project.
      deps = cc.makedepends(src)
      deps.each do |dep|
        makefile.distribute dep unless dep =~ /^\//
      end

      makefile.add_target(obj, deps, cc.rule)
      makefile.clean(obj)
      objs.push obj
    end

    # Generate the targets and rules for the link stage
    if library? and library_type == :static
       ar = @project.ar
       ar.output = output
       ar.objects = objs
       makefile.add_target ar.to_make
    else
      cc = @project.cc.clone
      cc.shared_library = library? and library_type == :shared
      cc.flags = @cflags
      cc.sources = sources
      cc.ld.flags = @ldflags
      @ldadd = [ @ldadd ] if @ldadd.kind_of?(String)
      @ldadd.each { |lib| cc.ld.library lib }
      cc.ld.output = @output
      cmd = cc.ld.rule 
      makefile.add_target(output, objs, cmd)
    end
    makefile.add_dependency('all', output)
    makefile.clean(output)
    makefile.distribute(sources) if distributable

    return makefile
  end
 
  # Return a hash containing Makefile dependencies
  def makedepends
    res = []

    if @sources.nil?
       log.error self.to_s
       raise 'Missing sources'
    end

    # Generate the targets and rules for each translation unit
    expand_sources(@sources).each do |src|
      next if src =~ /\.o$/
      cc = @project.cc.clone
      cc.flags = [ @cflags, '-E' ]
      cc.output = '-'
      cc.sources = src
      #TODO: topdir
      cmd = cc.command + Platform.dev_null_stderr

    end
    res
  end

  private

  def log
    Makeconf.logger
  end
end
