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

  def initialize(h)
    super(h, {
        :abi_major => '0',
        :abi_minor => '0',
    })
    @output = @id + Platform.shared_library_extension
    @output_type = 'shared library'
    @cflags.push '-fpic'
    @ldflags.push('-shared')
    @ldflags.push('-Wl,-export-dynamic') unless Platform.is_solaris?
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