# A buildable object like a library or executable
class Buildable

  attr_accessor :id, :installable, :distributable,
                :output, :output_type, :sources, :cflags, :ldflags, :ldadd, :rpath

  def initialize(h, extra_options = {})
    default = {
        :id => nil,
        :distributable => true,
        :installable => true,
        :extension => '',
        :cflags => [],
        :ldflags => [],
        :ldadd => [],
        :rpath => '',
        :sources => [],
        :depends => [],
    }
    default.merge! extra_options
    default.each do |k,v| 
      x = h.has_key?(k) ? h[k] : v
      raise ArgumentError.new("Missing argument: `#{k}'") \
          if x.nil?
      instance_variable_set('@' + k.to_s, x)
    end
    h.each do |k,v|
      raise ArgumentError.new("Invalid argument: `#{k}'") \
          unless default.has_key?(k)
    end
    @cflags = [ @cflags.split(' ') ] if @cflags.is_a? String
    @output = id
    @output_type = nil      # filled in by the derived class

    # Use glob(3) to expand the list of sources
    buf = []
    @sources.each { |src| buf << Dir.glob(src) }
    @sources = buf.flatten
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

  # Examine the sources and return a list of system headers as possible
  # dependencies.
  def system_headers
    res = []
    @sources.each do |src| 
      File.open(src, 'r').each do |line|
        if line =~ /^\s*#\s*include\s+\<(.*?)\>/
          res.push $1
        end
      end
    end
    res.sort.uniq
  end

  def finalize
  end

end
