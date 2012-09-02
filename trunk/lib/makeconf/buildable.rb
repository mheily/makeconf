# A buildable object like a library or executable
class Buildable

  attr_accessor :id, :project,
        :installable, :distributable,
        :localdep, :sysdep, :enable,
        :output, :output_type, :sources, :cflags, :ldadd, :rpath,
        :topdir

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    default = {
        :id => options[:id],
        :enable => true,
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

    # Local and system header dependencies for each @sources file
    # These are filled in by Compiler.makedepends()
    @localdep = {}
    @sysdep = {}

    # Filled in by sources=()
    @sources = []
    @source_code = {}

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
        @cflags = v
        @cflags = [ @cflags ] if @cflags.kind_of?(String)
      when :ldflags
        @ldflags = v
      when :ldadd
        @ldadd.push(v).flatten!
      when :project
        @project = v
      when :sources
        v = [ v ] if v.kind_of?(String)
        @sources = expand_sources(v)
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
    x.each { |src| buf << Dir.glob(src) }
    buf.flatten

# TODO: elsewhere
    # Ensure that all source files exist
#@sources.each do |src|
#      throw ArgumentError("#{src} does not exist") unless File.exist? src
#    end

#XXX-lame
#    # Read all source code into a single array
#    @source_code = {}
#    @sources.each { |x| @source_code[x] = File.readlines(x) }

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

  # Return a hash containing Makefile rules and targets
  # needed to build the object.
  #
  def build
    makefile = Makefile.new
    objs = []

    log.debug 'buildable = ' + self.pretty_inspect

    raise 'One or more source files are required' if @sources.empty?

    # Generate the targets and rules for each translation unit
    @sources.each do |src|
      object_suffix = ''
      if library? 
        if library_type == :shared
#DEADWOOD:cflags.push '-fpic'
        else
          object_suffix = '-static'
        end
      end
      obj = src.sub(/.c$/, object_suffix + Platform.object_extension)
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

      makefile.add_target(obj, [src, localdep[src]].flatten, cc.rule)
      makefile.clean(obj)
      objs.push obj
    end

    # Generate the targets and rules for the link stage
    if library? and library_type == :static
       cmd = Platform.archiver(output, objs)
    else
      cc = @project.cc.clone
      cc.shared_library = library? and library_type == :shared
      cc.flags = @cflags
      cc.sources = @sources
      @ldadd = [ @ldadd ] if @ldadd.kind_of?(String)
      @ldadd.each { |lib| cc.ld.library lib }
      cc.ld.output = @output
      cmd = cc.ld.rule 
    end
    makefile.add_target(output, objs, cmd)
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
    @sources.each do |src|
      cc = @project.cc.clone
      cc.flags = [ @cflags, '-E' ]
      cc.output = '-'
      cc.sources = src
      #TODO: topdir
      cmd = cc.command + Platform.dev_null_stderr

      # TODO: do @sysdep also
      @localdep[src] = []
      IO.popen(cmd).each do |x|
        if x =~ /^# \d+ "([^\/<].*\.h)"/
          @localdep[src].push $1
        end
      end
      @localdep[src].sort!.uniq!
      res.concat @localdep[src]

      # Generate a list of system header dependencies
      # FIXME: does a lot of duplicate work reading files in..
      buf = []
      @sysdep[src] = []
      buf.concat File.readlines(src)
      @localdep[src].each do |x|
        if File.exist? x
          buf.concat File.readlines(x)
        end
      end
      buf.each do |x|
        begin
          if x =~ /^#\s*include\s+<(.*?)>/
            @sysdep[src].push $1
          end
        rescue ArgumentError
          # FIXME: should give more info about which file and line
          warn "** WARNING: invalid multibyte sequence encountered in one of the source code files:"
        end
      end
      @sysdep[src].sort!.uniq!

    end
    res
  end

  private

  def log
    Makeconf.logger
  end
end
