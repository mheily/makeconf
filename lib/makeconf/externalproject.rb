# An external project is typically a third-party library dependency
# that does not use makeconf for it's build system.
#
class ExternalProject < Buildable
 
  require 'net/http'

  attr_accessor :uri

  def initialize(options)
    # KLUDGE - parent constructor will barf otherwise
    @uri = options[:uri]
    options.delete :uri

    super(options)

    @installable = false
    @distributable = false
  end

  # Examine the operating environment and set configuration options
  def configure
    printf "checking for external project #{@id}... "
    if File.exists?(@id)
       puts "yes"
       puts "*** Configuring #{@id}"
       system "cd #{@id} && ./configure" \
           or throw "Unable to configure #{@id}"
       puts "*** Done"
    else
       puts "no"
       download
    end
  end

  def build
     makefile = Makefile.new
     makefile.add_dependency('all', "#{@id}-build-stamp")
     makefile.add_target("#{@id}-build-stamp", [], 
             [
             "cd #{@id} && make",
             "touch #{@id}-build-stamp",
             ])
     makefile
  end


private

  # Download the project from an external source
  def download

#example for tarball
#    x = Net::HTTP.get(URI(uri))
#  end
  puts "downloading #{@uri}.. "

  if @uri =~ /^svn/
    system "svn co #{@uri} #{@id}" or throw "Unable to checkout working copy"

  else
    throw "Unsupported URI scheme #{@uri}"
  end

  end

  def log
      Makeconf.logger
  end
end
