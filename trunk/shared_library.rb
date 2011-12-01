
class SharedLibrary < Buildable

  def initialize(h)
    super(h, {
        :abi_major => '0',
        :abi_minor => '0',
        :enable_shared => true,
    })
    @output = @id + Platform.shared_library_extension
    @output_type = 'shared library'
  end

  def build
  throw 'FIXME'
    libfile = @id + Platform.shared_library_extension
    cc = @compiler.clone
    cc.is_library = true
    cc.is_shared = true
    cc.sources = @sources
    cc.append_cflags(@cflags)

    deps = cc.objs.sort

    if Platform.is_windows?
      @makefile.add_target(libfile, deps, 'link.exe /DLL /OUT:$@ ' + deps.join(' '))
      # FIXME: shouldn't we use cmd to build the dll ??
    else
      cc.ld.export_dynamic
      cc.ld.soname(@id + '.' + @abi_major)
      @makefile.merge!(cc.to_make(libfile))
    end 
    @makefile.install(libfile, '$(LIBDIR)')
    @makefile.clean(cc.objs)
  end

end
