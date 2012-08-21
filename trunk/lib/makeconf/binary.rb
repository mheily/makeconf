# An executable binary file
class Binary < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    super(options)
    @output_type = 'binary'
  end

  def DEADWOOD_build
    binfile = @id + Platform.executable_extension
    cc = @compiler.clone
    cc.is_library = false
    cc.sources = @sources
    cc.output = binfile

#XXX-BROKEN cc.add_targets(@makefile)

    @makefile.merge!(cc.to_make(binfile))

    @makefile.clean(cc.objs)
    @makefile.install(binfile, '$(BINDIR)', { 'mode' => '755' }) \
        if @installable
    @output.push binfile
    super()
  end
          
end

