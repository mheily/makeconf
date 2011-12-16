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

  # Return the complete command line to compile an object
  def command(h)
    res = []

    throw 'Invalid linker' unless @ld.is_a?(Linker)
    throw ArgumentError.new unless h.is_a? Hash
    throw ArgumentError.new unless h.has_key? :output
    [:cflags, :ldflags, :ldadd].each do |x|
      h[x] = [] unless h.has_key? x
    end
    [:rpath, :stage].each do |x|
      h[x] = '' unless h.has_key? x
    end

    cc = h[:cc] || @path
    ld = @ld.clone
    ldadd = h[:ldadd]
    cflags = h[:cflags]
    ldflags = [ '-o', h[:output] ]
    ldflags.push h[:ldflags]

    ld.rpath = h[:rpath] if h[:rpath].length > 0

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

    if h[:stage] == :compile
      res = [ @path, '-c', cflags, inputs ]
    elsif h[:stage] == :link
      res = [ @path, ldflags, ld.to_s, inputs, ldadd ]
    elsif h[:stage] == :combined
      res = [ @path, cflags, ldflags, inputs, ldadd ]
    else
      throw 'invalid stage'
    end

    res.flatten.join(' ')
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

  # Compile and link a test program
  def test_link(code)
    test_compile(code, :combined)
  end

  # Compile a test program
  def test_compile(code, stage = :compile)

    # Write the code to a temporary source file
    f = Tempfile.new(['testprogram', '.' + @extension]);
    f.print code
    f.flush
    objfile = f.path + '.out'

    # Run the compiler
    cmd = command(:stage => stage, :sources => f.path, :output => objfile) + Platform.dev_null
    rc = system cmd

    File.unlink(objfile) if rc
    return rc
  end

  
  # Return a hash containing Makefile dependencies
  def makedepends(b)
    res = []
    raise ArgumentError unless b.kind_of? Buildable

    # Generate the targets and rules for each translation unit
    b.sources.each do |src|
      cflags = [ b.cflags, '-E' ]
      cmd = command(
                :stage => :compile,
                :output => '-', 
                :sources => src, 
                :cflags => cflags
              ) + Platform.dev_null_stderr

      # TODO: do b.sysdep also
      b.localdep[src] = []
      IO.popen(cmd).each do |x|
        if x =~ /^# \d+ "([^\/<].*\.h)"/
          b.localdep[src].push $1
        end
      end
      b.localdep[src].sort!.uniq!
      res.concat b.localdep[src]

      # Generate a list of system header dependencies
      # FIXME: does a lot of duplicate work reading files in..
      buf = []
      b.sysdep[src] = []
      buf.concat File.read(src).split(/\r?\n/)
      b.localdep[src].each do |x|
        if File.exist? x
          buf.concat File.read(x).split(/\r?\n/)
        end
      end
      buf.each do |x|
        if x =~ /^#\s*include\s+\<(.*?)\>/
          b.sysdep[src].push $1
        end
      end
      b.sysdep[src].sort!.uniq!

    end
    res
  end

  # Return a hash containing Makefile rules and targets
  def build(b)
    raise ArgumentError unless b.kind_of? Buildable
    makefile = Makefile.new
    objs = []

    # Generate the targets and rules for each translation unit
    b.sources.each do |src|
      object_suffix = ''
      cflags = [ b.cflags ]
      if b.library? 
        if b.library_type == :shared
          cflags.push '-fpic'
        else
          object_suffix = '-static'
        end
      end
      obj = src.sub(/.c$/, object_suffix + Platform.object_extension)
      cmd = command(
              :stage => :compile,
              :output => obj, 
              :sources => src, 
              :cflags => cflags
              )
      makefile.add_target(obj, [src, b.localdep[src]].flatten, cmd)
      makefile.clean(obj)
      objs.push obj
    end

    # Generate the targets and rules for the link stage
    if b.library? and b.library_type == :static
       cmd = Platform.archiver(b.output, objs)
    else
      cmd = command(
              :stage => :link,
              :output => b.output, 
              :sources => objs, 
              :ldflags => b.ldflags,
              :ldadd => b.ldadd,
              :rpath => b.rpath
              )
    end
    makefile.add_target(b.output, objs, cmd)
    makefile.add_dependency('all', b.output)
    makefile.clean(b.output)
    makefile.distribute(b.sources) if b.distributable

    return makefile
  end

  private

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
    unless system(cmd)
       puts "not found"
       print " -- tried: " + cmd
       raise
    end

    puts res
    res
  end

end

class CCompiler < Compiler

  attr_accessor :output_type

  def initialize
    @output_type = nil
    super('C', '.c')
    printf "checking for a C compiler.. "
    @path = search(['cc', 'gcc', 'clang', 'cl.exe'])

    # GCC on Solaris 10 produces 32-bit code by default, so add -m64
    # when running in 64-bit mode.
    if Platform.is_solaris? and Platform.word_size == 64
       @cflags += ' -m64'
       @ldflags += '-m64'
       @ldflags += ' -R/usr/sfw/lib/amd64' if Platform.is_x86?
    end
  end

end