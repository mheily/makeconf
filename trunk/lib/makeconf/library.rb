# A generic Library class that builds both shared and static

class Library < Buildable

  attr_reader :buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @buildable = [SharedLibrary.new(options), StaticLibrary.new(options)]
  end

end

class SharedLibrary < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    id = options[:id]

    super(options)
    @abi_major = 0
    @abi_minor = 0
    @output = 'lib' + id + Platform.shared_library_extension
    @output_type = 'shared library'
#FIXME: @cc.ld.flags.push('-export-dynamic') unless Platform.is_solaris?
  end

end

class StaticLibrary < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    id = options[:id]
    super(options)
    @output = id + Platform.static_library_extension
    @output_type = 'static library'

# FIXME: clashes with shared objects
#      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
  end

end
