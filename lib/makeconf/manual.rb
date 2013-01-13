# Generates program manuals (man pages, etc.)
# Currently it only handles troff/mdoc manpages, but in the future it could
# generate multiple formats from a single source

class Manual < Buildable

  def initialize(source, options = {})
    @source = source
    @format = 'man'

    # Determine the manpage section
    @section = @source.sub(/^.*\./, '')

    raise ArgumentError unless options.kind_of?(Hash)
    super(options)
  end

  def install(installer)

    installer.install(
        :sources => @source,
        :dest => '$(MANDIR)/man' + @section,
        :mode => '644') 
  end

  def compile(cc)
    mk = Makefile.new
    mk.distribute(@source)
    return mk
  end

  def link(ld)
  end

  def makedepends
    []
  end

end
