# An executable binary file used for testing
class Test < Binary

  def initialize(options)
    super(options)

    @installable = false
    @distributable = false


    # Assume that unit tests should be debuggable
    @cflags.push('-g', '-O0') unless Platform.is_windows?
  end

  def compile(cc)
    makefile = super(cc)

    unless SystemType.host =~ /-androideabi$/
      makefile.add_dependency('check', @id)
      makefile.add_rule('check', './' + @id)
    end

    return makefile
  end

  def install(installer)
    # Test programs do not get installed
  end

  def link(ld)
    unless Platform.is_windows?
# FIXME: want to do this, but parent overrides ldflags entirely
#ld.rpath = '.'
    @ldflags.push ['rpath', '.']    # workaround
    end
    super(ld)
  end
end
