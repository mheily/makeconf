# Processes source code files to produce intermediate object files.
#
class Compiler

  require 'tempfile'

  attr_accessor :ld

  def initialize(language, extension)
    @language = language
    @extension = extension
    @ld = Linker.new()
  end

  def clone
    # does this deep copy the linker?
    Marshal.load(Marshal.dump(self))
  end

  # Search for a suitable compiler
  def search(compilers)
    res = nil
    printf "checking for a " + @language + " compiler.. "
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
    unless system(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    @path = res
  end

  # Return the intermediate object files for each source file
  def object_files(sources)
    res = []
    sources.sort.each do |s|
      res.push s.sub(/.c$/, Platform.object_extension)
    end
    res
  end

  # Return the complete command line to compile an object
  def command(h)
    throw 'Invalid linker' unless @ld.is_a?(Linker)

    throw ArgumentError.new unless h.is_a? Hash
    throw ArgumentError.new unless h.has_key? :output
    [:cflags, :ldflags, :ldadd].each do |x|
      h[x] = [] unless h.has_key? x
    end

    ldadd = h[:ldadd]
    cflags = h[:cflags]
    ldflags = h[:ldflags]

    cflags.push '-c'

    if @path.match(/cl.exe$/i)
      cflags.push '/Fo', h[:output]
    else
      cflags.push '-o', h[:output]
    end

    # KLUDGE: remove things that CL.EXE doesn't understand
    # DEADWOOD: do this somewhere else
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

    inputs = h[:sources]
    inputs = [ inputs ] if inputs.is_a? String
    throw 'One or more sources are required' unless inputs.count

    [ @path, cflags, ldflags, @ld.to_s, inputs, ldadd ].flatten.join(' ')
  end

  # Test if the compiler supports a command line option
  def has_option(opt)

    # Create a simple test file
    f = Tempfile.new(['testprogram', @extension]);
    f.puts 'int main() { }'
    f.flush

    cmd = [ @path, opt, '-c', f.path ].join(' ') + Platform.dev_null
    system cmd
  end

  # Check if a header is available
  def check_header(path)
    test_compile("#include <" + path + ">")
  end

  # Compile a test program
  def test_compile(code)

    # Write the code to a temporary source file
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
    objfile = f.path + '.out'

    # Run the compiler
    cc = self.clone
    cc.sources = f.path
    cmd = command(objfile) + Platform.dev_null
    rc = system cmd

    File.unlink(objfile) if rc
    return rc
  end

  # Return a hash containing Makefile rules and targets
  def build(b)
    raise ArgumentError unless b.kind_of? Buildable
    makefile = Makefile.new

    objs = object_files(b.sources).sort

    # Generate the targets and rules for each translation unit
    objs.each do |d| 
      src = d.sub(/#{Platform.object_extension}$/, '.c')
      cflags = [ b.cflags ]
      if b.library? and b.library_type == :shared
        cflags.push '-fpic'
      end
      cmd = command(:output => d, 
              :sources => src, 
              :cflags => cflags,
              :ldflags => b.ldflags,
              :ldadd => b.ldadd,
              :rpath => b.rpath
              )
      makefile.add_target(d, src, cmd)
      makefile.clean(d)
    end

    # Generate the targets and rules for the link stage
    cflags = [ "-o #{b.output}" ]
    if b.library? and b.library_type == :shared
       cflags.push('-shared')
       cflags.push('-Wl,-export-dynamic') unless Platform.is_solaris?
    end
    cmd = [@path, cflags, '$(CFLAGS)', b.ldflags, '$(LDFLAGS)', objs, b.ldadd, '$(LDADD)'].flatten.join(' ')
    makefile.add_target(b.output, objs, cmd)
    makefile.add_dependency('all', b.output)
    makefile.clean(b.output)
    makefile.distribute(b.sources) if b.distributable

    return makefile
  end

end

class CCompiler < Compiler

  attr_accessor :output_type

  def initialize
    @output_type = nil
    super('C', '.c')
    search(['cc', 'gcc', 'clang', 'cl.exe'])

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       @cflags += ' -m64'
       @ldflags += '-m64'
       @ldflags += ' -R/usr/sfw/lib/amd64' if Platform.is_x86?
    end
  end

end
