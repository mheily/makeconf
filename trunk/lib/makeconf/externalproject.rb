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
    @configure = options[:configure]  # options passed to ./configure 
    options.delete :configure
    @configure = '' if @configure.nil?

    super(options)

    @installable = false
    @distributable = false
  end

  # Examine the operating environment and set configuration options
  def configure
    printf "checking for external project #{@id}... "
    if File.exists?(@id)
       puts "yes"
    else
       puts "no"
       download
    end

    # KLUDGE: passthrough certain options
    passthru = []
    Makeconf.original_argv.each do |x|
      passthru.push x if x =~ /^--(host|with-ndk|with-sdk)/
      warn x
    end
    @configure += passthru.join ' '

    # Run the autoconf-style ./configure script
    puts "*** Configuring #{@id} using ./configure #{@configure}"
    system "cd #{@id} && ./configure #{@configure}" \
        or throw "Unable to configure #{@id}"
    puts "*** Done"
  end

  def build
     makefile = Makefile.new
     makefile.add_dependency('all', "#{@id}-build-stamp")
     makefile.add_target("#{@id}-build-stamp", [], 
             [
             "cd #{@id} && make",
             "touch #{@id}-build-stamp",
             ])
     makefile.add_rule('check', [ "cd #{@id} && make check" ])
     makefile.add_rule('clean', Platform.rm("#{@id}-build-stamp"))
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
