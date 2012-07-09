# TODO: Have a generic Library class that builds both shared and static
#
#class Library < Buildable
#
#  def initialize(h)
#    super(h, {
#        :abi_major => '0',
#        :abi_minor => '0',
#    })
#  end
#
#end

class SharedLibrary < Buildable

  def initialize(id)
    raise ArgumentError if id.nil?

    super(id)
    @abi_major = 0
    @abi_minor = 0
    @output = id + Platform.shared_library_extension
    @output_type = 'shared library'
    if Platform.is_windows?
      @ldflags.push '/DLL'
    else
      @cflags.push '-fpic', '-shared'
      @ldflags.push('-export-dynamic') unless Platform.is_solaris?
    end
  end

end

class StaticLibrary < Buildable

  def initialize(h)
    super(h)
    @output = @id + Platform.static_library_extension
    @output_type = 'static library'

# FIXME: clashes with shared objects
#      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
  end

end
