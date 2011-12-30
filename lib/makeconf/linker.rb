# A linker combines multiple object files into a single executable or library file. 
#
class Linker

  def initialize
    @flags = []
    @cflags = [] # KLUDGE: passed to the compiler w/o the '-Wl,' prefix
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
    @cflags.push ['-L', dir]
  end

  # Returns the linker flags suitable for passing to the compiler
  def to_s
     tok = []
     tok.push @cflags
     @flags.each do |f|
        if f.kind_of?(Array)
          tok.push '-Wl,-' + f[0] + ',' + f[1]
        else
          tok.push '-Wl,-' + f
        end
     end
     return ' ' + tok.join(' ')
  end

  # TODO - not used yet
  def command
    # windows: 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
    # linux: 'cc ' .... (see Compiler::)
  throw 'stub'
  end

  # Try to determine a usable default set of linker flags
  def default_flags
    ldflags = []

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       ldflags.push '-m64'
       ldflags.push '-R', '/usr/sfw/lib/amd64' if Platform.is_x86?
    end

    ldflags
  end

end

