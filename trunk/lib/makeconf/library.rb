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
#pp @buildable
#    throw 'mmm'

    # Build a list of all source files within each component library
    sources = []
    @buildable.each { |x| sources.push x.sources }
    sources.flatten!
    sources.each { |x| x.gsub!(/\.c$/, '.o') }
#pp sources
#    throw 'mmm'

    @buildable.push StaticLibrary.new(
            :id => options[:id],
            :sources => sources
            )
  end

  def build
    makefile = super()

    objs = []
    @buildable.each { |b| objs.push b.objects }
    pp objs
    throw 'ii'

#makefile.add_target('foo', [src, localdep[src]].flatten, cc.rule)
#    makefile.clean(obj)
    makefile
  end

end

class UnionStaticLibrary < StaticLibrary
end
