# An executable binary file used for testing
class Test < Binary

  def initialize(options)
    super(options)

    @installable = false
    @distributable = false

    # Assume that unit tests should be debuggable
    @cflags.push('-g', '-O0') unless Platform.is_windows?
  end


  def build
    makefile = super()

    unless SystemType.host =~ /-androideabi$/
      makefile.add_dependency('check', @id)
      makefile.add_rule('check', './' + @id)
    end

    return makefile
  end

end
