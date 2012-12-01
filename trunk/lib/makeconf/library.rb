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
    @output = id + Platform.shared_library_extension
    @output = 'lib' + @output unless @output =~ /^lib/ or Platform.is_windows?
    @output_type = 'shared library'
#FIXME: @cc.ld.flags.push('-export-dynamic') unless Platform.is_solaris?
  end

  def install(installer)
    installer.install(
        :dest => '$(LIBDIR)',
        :rename => "#{@output}.#{@abi_major}.#{@abi_minor}",
        :sources => @output,
        :mode => '0644',
    )
  end

end

class StaticLibrary < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    id = options[:id]
    super(options)
    @output = id + Platform.static_library_extension
    @output = 'lib' + @output unless @output =~ /^lib/ or Platform.is_windows?
    @output_type = 'static library'

# FIXME: clashes with shared objects
#      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
  end

  def install(installer)
    # NOOP - No reason to install a static library
  end

end

#
# UnionLibrary - combine multiple static libraries into a single library.
#
#   The :sources for this library should be an array of Library objects
#
class UnionLibrary < Library

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @buildable = []
    options[:sources].each do |x|
      x.buildable.each do |y|
        @buildable.push y if y.kind_of?(StaticLibrary)
      end
    end
    @buildable.flatten!

    # Build a list of all source files within each component library
    sources = []
    @buildable.each { |x| sources.push x.sources }
    sources.flatten!

    @buildable.push StaticLibrary.new(
            :id => options[:id],
            :sources => sources
            )
  end
end
