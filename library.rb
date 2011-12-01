class Library < Buildable

  def initialize(h)
    super(h, {
        :abi_major => '0',
        :abi_minor => '0',
        :enable_shared => true,
        :enable_static => false,
    })
    if @enable_shared and @enable_static
       raise ArgumentError.new('Must choose either static or shared library type')
    end
    if @enable_shared 
      @output = @id + Platform.shared_library_extension
      @output_type = 'shared library'
      @cflags.push '-fpic'
      @ldflags.push('-shared')
      @ldflags.push('-Wl,-export-dynamic') unless Platform.is_solaris?
    else
      @output = @id + Platform.static_library_extension
      @output_type = 'static library'
    end
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

#### DEADWOOD: these extra classes aren't used

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
