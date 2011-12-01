
class StaticLibrary < Buildable

  def initialize(h)
    super(h, { :enable_static => true, })
  end

  def build
    libfile = @id + Platform.static_library_extension
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = false
    cc.sources = @sources
    cc.append_cflags(@cflags)
    cmd = cc.command(libfile)
    deps = cc.objs.sort
    deps.each do |d| 
      src = d.sub(/-static#{Platform.object_extension}$/, '.c')
      output = Platform.is_windows? ? ' /Fo' + d : ' -o ' + d
      @makefile.add_target(d, src, cmd + output + ' ' + src) 
    end
    @makefile.add_target(libfile, deps, Platform.archiver(libfile, deps))
    @makefile.clean(cc.objs)
    @output.push libfile
  end
end
