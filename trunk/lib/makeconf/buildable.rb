# A buildable object like a library or executable
class Buildable

  attr_accessor :id, :installable, :distributable,
        :localdep, :sysdep, :enable,
        :output, :output_type, :sources, :cflags, :ldflags, :ldadd, :rpath,
        :topdir

  def initialize(id)
    default = {
        :id => id,
        :enable => true,
        :distributable => true,
        :installable => true,
        :extension => '',
        :cflags => [],
        :ldflags => [],
        :ldadd => [],
        :rpath => '',
        :sources => [],
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
  end

  def sources=(x)
    raise ArgumentError('Wrong type') unless x.is_a? Array

    # Use glob(3) to expand the list of sources
    buf = []
    x.each { |src| buf << Dir.glob(src) }
    @sources = buf.flatten

    # Ensure that all source files exist
    @sources.each do |src|
      throw ArgumentError("#{src} does not exist") unless File.exist? src
    end

    # Read all source code into a single array
    @source_code = {}
    @sources.each { |x| @source_code[x] = File.readlines(x) }
  end

  def cflags=(x)
    case x.is_a?
    when String
      @cflags = [ x.split(' ') ]
    when Array
      @cflags = s
    else
      raise ArgumentError
    end
  end

  def parse(yaml)
    %w{name enable distributable installable extension
       topdir rpath}.each do |k|
       v = yaml[k]
       instance_variable_set('@' + k, v) unless v.nil?
    end

    # Parse simple textual child elements
    %w{cflags ldflags ldadd depends sources}.each do |k|
      instance_variable_set('@' + k, yaml[k]) if yaml.has_key? k
    end

    self
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

end
