# An executable binary file used for testing
class Test < Binary

  def initialize(options)
    super(options)

    @installable = false
    @distributable = false

    # Assume that unit tests should be debuggable
    @cflags.push('-g', '-O0') unless Platform.is_windows?
  end

# FIXME: NEED to_make() overrides
#    # Add unit tests
#    @test.each do |x| 
#      makefile.add_dependency('check', x.id)
#      makefile.add_rule('check', './' + x.id)
#    end

  def build
        # FIXME: @makefile.add_target('check', deps, deps.map { |d| './' + d })
#    @build.push x
#        @test.push x
#    end
    super()
  end

end
