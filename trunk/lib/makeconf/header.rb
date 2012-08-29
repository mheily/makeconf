# A generic Header class that installs header files into $(PKGINCLUDEDIR)

class Header < Buildable

  def initialize(options)
    raise ArgumentError unless options.kind_of?(Hash)
    @sources = []

    super(options)
  end

  def build
    mk = Makefile.new

    mk.distribute(@sources)

    @project.installer.install(
        :sources => @sources,
        :dest => '$(INCLUDEDIR)',  #XXX- should be PKGincludedir
        :mode => '644' 
     ) 

    return mk
  end

end
