# The archiver creates a static library from one or more object files
#
class Archiver

  attr_accessor :output, :objects
  attr_reader :path

  def initialize
    @flags = 'cru'      # GNU-specific; more portable is 'rcs'
    @objects = []
    @output = nil
    @path = nil

    if ENV['LD']
      self.path = ENV['LD']
    end
  end

  # Set the full path to the archiver executable
  def path=(p)
    @path = p
    # TODO: Support non-GNU archivers
    #if `#{@path} --version` =~ /^GNU ar/
#  @gcc_flags = false
#    end
  end

  def command
    cmd = [ @path, flags, @output, @objects].flatten.join(' ')
    log.debug "Archiver command = `#{cmd}'"
    cmd
  end

  # Return the command formatted as a Makefile rule
  def to_make
    Target.new(@output, @objects, command)
  end

private

  def log
    Makeconf.logger
  end

end
