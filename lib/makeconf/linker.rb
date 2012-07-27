# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  attr_accessor :output, :objects, :quiet, :shared_library
  attr_reader :path

  def initialize
    @flags = []
    @objects = []
    @output = nil
    @shared_library = false
    @ldadd = []
    @quiet = false          # If true, output will be suppressed

    # Determine the path to the linker executable
    @path = nil
#TODO: support using Clang/GCC on windows
#if vendor == 'Microsoft'
    if Platform.is_windows?
      @path = 'LINK.EXE'
    else
      @path = 'cc' #XXX-FIXME horrible
    end
  end

  def clone
    Marshal.load(Marshal.dump(self))
  end

  # Sets the ELF soname to the specified string
  def soname(s)
    unless Platform.is_windows?
     @flags.push ['soname', s]
    end
  end

  # Add all symbols to the dynamic symbol table (GNU ld only)
  def export_dynamic
    unless Platform.is_windows?
     @flags.push 'export-dynamic'
    end
  end

  # Override the normal search path for the dynamic linker
  def rpath=(dir)
    if Platform.is_solaris?
      @flags.push ['R', dir]
    elsif Platform.is_linux?
      @flags.push ['-rpath', dir]
    elsif Platform.is_windows?
      # XXX-FIXME Windows does not support the rpath concept
      return
    else
      throw 'Unsupported OS'
    end
    @flags.push ['-L', dir]
  end

  # Returns the linker flags suitable for passing to the compiler
  def flags
     tok = []

    # Set the output path
    throw 'Output pathname is required' if @output.nil?
    if Platform.is_windows?
      tok.push "/OUT:\"#{@output}"
    else
      tok.push '-o', @output
    end

    # Enable shared library output
    if @shared_library
      if Platform.is_windows?
        tok.push '/DLL'
      else
        tok.push '-shared'
        tok.push '-fpic'        # TODO: sometimes -fPIC is needed
      end
    end

    # Assume that we want to link with shared libraries
    # built within this project
    tok.push '-L', '.'

    @flags.each do |f|
       if f.kind_of?(Array)
         tok.push '-Wl,-' + f[0] + ',' + f[1]
       else
         tok.push '-Wl,-' + f
       end
    end

    return ' ' + tok.join(' ')
  end

  def command
    # windows: 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
    # linux: 'cc ' .... (see Compiler::)
    cmd = [ @path, flags, @objects, @ldadd ].flatten.join(' ')
    cmd += Platform.dev_null if @quiet
    log.debug "Linker command = `#{cmd}'"

    return cmd
  end

  # Return the command formatted as a Makefile rule
  def rule
     ['$(LD)', flags, '$(LDFLAGS)', @objects, @ldadd, '$(LDADD)'].flatten.join(' ')
  end

  # Execute the linker command
  def link
    throw 'STUB'
  end

  def flags=(tok)
    @flags = default_flags
    if tok.kind_of?(Array)
      @flags.concat tok
    elsif tok.kind_of?(String)
      @flags.concat tok.split(' ') #XXX-broken, will not handle things like '-rpath /foo'
    else
      throw 'Invalid flag type'
    end
  end

  # Try to determine a usable default set of linker flags
  def default_flags
    ldflags = []

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       ldflags.push '-m64'
       ldflags.push '-R/usr/sfw/lib/amd64' if Platform.is_x86?
    end

    ldflags
  end

  # Add one or more libraries to the list of files to link
  def library(lib)
    case lib.class.to_s
    when 'Array'
      tok = lib
    when 'String'
      tok = lib.split(' ')
    else
      throw "Invalid value: #{lib.class}"
    end
    @ldadd.concat tok
  end

private

  def log
    Makeconf.logger
  end

end

