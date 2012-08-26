# Processes source code files to produce intermediate object files.
#
class Compiler

  require 'tempfile'

  attr_reader :ld

  def initialize(language, extension)
    @language = language
    @extension = extension
    @ld = Linker.new()
    windows_init if Platform.is_windows?
    @flags = []
    @sources = []     # List of input files
    @quiet = false          # If true, output will be suppressed

    # TODO:
    # If true, all source files will be passed to the compiler at one time.
    # This will also combine the link and compilation phases.
    # See: the -combine option in GCC
    #@combine = false

  end

  def sources=(a)
    a = [ a ] if a.kind_of?(String)
    throw 'Array input required' unless a.kind_of?(Array)
    @sources = a
    @ld.objects = a.map { |x| x.sub(/\.c$/, '.o') } #FIXME: hardcoded to C
  end

  def cflags
    @flags
  end

  def clone
    Marshal.load(Marshal.dump(self))
  end

  # Return the intermediate object files for each source file
  def object_files(sources)
    res = []
    sources.sort.each do |s|
      res.push s.sub(/.c$/, Platform.object_extension)
    end
    res
  end

  def quiet=(b)
    ld.quiet = b
    @quiet = b
  end

  def output=(s)
    @output = s
    ld.output = s
  end

  def makefile
    m = Makefile.new
    m.define_variable('CC', ':=', @path)
    m.define_variable('LD', ':=', @ld.path)
    return m
  end

  # Return the command formatted as a Makefile rule
  def rule
    [ '$(CC)', '-c', flags, '$(CFLAGS)', @sources ].flatten.join(' ')
  end

  # Return the complete command line to compile an object
  def command
    log.debug self.pretty_inspect

    throw 'Invalid linker' unless @ld.is_a?(Linker)
    throw 'One or more source files are required' unless @sources.length > 0
#      cflags = default_flags
#      cflags.concat @flags
#    end
#    throw cflags

#    topdir = h[:topdir] || ''
#    ld = @ld.clone
#    ldadd = h[:ldadd]
#    ld.flags = h[:ldflags]
#    ld.output = Platform.pathspec(h[:output])
#    ld.rpath = h[:rpath] if h[:rpath].length > 0

#    inputs = h[:sources]
#    inputs = [ inputs ] if inputs.is_a? String
#    inputs = inputs.map { |x| Platform.pathspec(topdir + x) }
#    throw 'One or more sources are required' unless inputs.count

#TODO:if @combine
# return [ @path, cflags, '-combine', ldflags, inputs, ldadd ].flatten.join(' ')
#
    
    cmd = [ @path, '-c', flags, @sources ].flatten.join(' ')

    cmd += Platform.dev_null if @quiet

    log.debug "Compiler command: #{cmd}"

    cmd
  end

  def flags
    tok = []

   # KLUDGE: remove things that CL.EXE doesn't understand
#    if @path.match(/cl.exe$/i)
#      cflags += ' '
#      cflags.gsub!(/ -Wall /, ' ') #  /Wall generates too much noise
#      cflags.gsub!(/ -Werror /, ' ')  # Could use /WX here
#      cflags.gsub!(/ -W /, ' ')
#      cflags.gsub!(/ -Wno-.*? /, ' ')
#      cflags.gsub!(/ -Wextra /, ' ')
#      cflags.gsub!(/ -fpic /, ' ')
#      cflags.gsub!(/ -std=.*? /, ' ')
#      cflags.gsub!(/ -pedantic /, ' ')
#    end

    # Set the output path
    unless @output.nil?
      outfile = Platform.pathspec(@output)
      if vendor == 'Microsoft'
        tok.push '"-IC:\Program Files\Microsoft Visual Studio 10.0\VC\include"' # XXX-HARDCODED
        tok.push '/Fo' + outfile
        tok.push '/MD'
      else
        tok.push '-o', outfile
      end
    end

    if @ld.shared_library 
      if Platform.is_windows?
        throw 'FIXME'
      else
        tok.push '-fpic' 
      end
    end

    tok.join(' ')
  end

  def flags=(s)
    @flags = s
    @flags = @flags.split(' ') if @flags.kind_of?(String)
  end

  # Enable compiler and linker options to create a shared library
  def shared_library=(b)
    case b
    when true
      if Platform.is_windows?
        # noop
      else
        @flags.push '-fpic'
        @ld.shared_library = true
      end
    when false
      throw 'FIXME - STUB'
    else
      throw 'Invalid value'
    end
  end

  # Test if the compiler supports a command line option
  def has_option(opt)

    # Create a simple test file
    f = Tempfile.new(['testprogram', @extension]);
    f.puts 'int main() { }'
    f.flush

    cmd = [ @path, opt, '-c', f.path ].join(' ') + Platform.dev_null
    Platform.execute cmd
  end

  # Check if a header is available
  def check_header(path)
    test_compile("#include <" + path + ">")
  end

  # Compile and link a test program
  def test_link(code)
    test_compile(code, :combined)
  end

  # Run the compilation command
  def compile
    cmd = self.command
    log.debug "Invoking the compiler"
    rc = Platform.execute cmd
    log.debug "Compilation complete; rc=#{rc.to_s}"
  end

  # Compile a test program
  def test_compile(code, stage = :compile)

    # Write the code to a temporary source file
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
###objfile = f.path + '.out'

    # Run the compiler
    cc = self.clone
    cc.sources = f.path
###    cc.output = objfile
    cc.quiet = true
    rc = cc.compile

###    File.unlink(objfile) if rc
    return rc
  end

 
  # Try to determine a usable default set of compiler flags
  def default_flags
    cflags = []

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       cflags.push '-m64'
    end

    cflags
  end

  private

  # Special initialization for MS Windows
  def windows_init
    # FIXME: hardcoded to VS10 on C: drive, should pull the information from vcvars.bat
    ENV['PATH'] = 'C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\;C:\Program Files\Microsoft Visual Studio 10.0\VC\BIN;C:\Program Files\Microsoft Visual Studio 10.0\Common7\Tools' + ENV['PATH']
    ENV['INCLUDE'] = 'INCLUDE=C:\Program Files\Microsoft Visual Studio 10.0\VC\INCLUDE;C:\Program Files\Microsoft SDKs\Windows\v7.0A\include;'
    ENV['LIB'] = 'C:\Program Files\Microsoft Visual Studio 10.0\VC\LIB;C:\Program Files\Microsoft SDKs\Windows\v7.0A\lib;'
    ENV['LIBPATH'] = 'C:\WINDOWS\Microsoft.NET\Framework\v4.0.30319;C:\WINDOWS\Microsoft.NET\Framework\v3.5;C:\Program Files\Microsoft Visual Studio 10.0\VC\LIB;'
    ENV['VCINSTALLDIR'] = "C:\Program Files\\Microsoft Visual Studio 10.0\\VC\\"
    ENV['VS100COMNTOOLS'] = "C:\\Program Files\\Microsoft Visual Studio 10.0\\Common7\\Tools\\"
    ENV['VSINSTALLDIR'] = "C:\\Program Files\\Microsoft Visual Studio 10.0\\"
    ENV['WindowsSdkDir'] = "C:\\Program Files\\Microsoft SDKs\\Windows\\v7.0A\\"
  end

  # Search for a suitable compiler
  def search(compilers)
    res = nil
    if ENV['CC']
      res = ENV['CC']
    else
      compilers.each do |command|
         if Platform.which(command)
           res = command
           break
         end
      end
    end

    # FIXME: kludge for Windows, breaks mingw
    if Platform.is_windows?
        res = 'cl.exe'
    end

    throw 'No compiler found' if res.nil? || res == ''

    if Platform.is_windows? && res.match(/cl.exe/i)
        help = ' /? <NUL'
    else
        help = ' --help'
    end
    
    # Verify the command can be executed
    cmd = res + help + Platform.dev_null
    unless Platform.execute(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    res
  end

  # Return the name of the compiler vendor
  def vendor
    if @path.match(/cl.exe$/i)
      'Microsoft'
    else
      'Unknown'
    end
  end
end

class CCompiler < Compiler

  attr_accessor :output_type
  attr_reader :path

  def initialize
    @output_type = nil
    super('C', '.c')
    printf "checking for a C compiler.. "
    @path = search(['cc', 'gcc', 'clang', 'cl.exe'])
  end

private

  def log
    Makeconf.logger
  end

end