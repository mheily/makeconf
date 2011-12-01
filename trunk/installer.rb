# An installer copies files from the current directory to an OS-wide location
class Installer

  attr_reader :dir
  attr_accessor :package

  def initialize
    @items = []         # Items to be installed
    @project = nil
    @path = nil

    # Set default installation paths
    @dir = {
        'prefix' => '/usr/local',
        'exec-prefix' => '$(PREFIX)',

        'bindir' => '$(EPREFIX)/bin',
        'datarootdir' => '$(PREFIX)/share',
        'datadir' => '$(DATAROOTDIR)',
        'docdir' => '$(DATAROOTDIR)/doc/$(PACKAGE)',
        'includedir' => '$(PREFIX)/include',
        'infodir' => '$(DATAROOTDIR)/info',
        'libdir' => '$(EPREFIX)/lib',
        'libexecdir' => '$(EPREFIX)/libexec',
        'localedir' => '$(DATAROOTDIR)/locale',
        'localstatedir' => '$(PREFIX)/var',
        'mandir' => '$(DATAROOTDIR)/man',
        'oldincludedir' => '/usr/include',
        'sbindir' => '$(EPREFIX)/sbin',
        'sysconfdir' => '$(PREFIX)/etc',
        'sharedstatedir' => '$(PREFIX)/com',
        
        #TODO: document this
        #DEPRECATED: htmldir, dvidir, pdfdir, psdir
    }
 
  end

  # Examine the operating environment and set configuration options
  def configure(project)
    @project = project
    printf 'checking for a BSD-compatible install.. '
    if Platform.is_windows?
       puts 'not found'
    else
       @path = search() or throw 'No installer found'
       printf @path + "\n"
    end
  end

  # Parse command line options.
  # Should only be called from Makeconf.parse_options()
  def parse_options(opts)
    opts.separator ""
    opts.separator "Installation options:"

    @dir.sort.each do |k, v|
       opts.on('--' + k + ' [DIRECTORY]', "TODO describe this [#{v}]") do |arg|
          @dir[k] = arg
       end
    end

  end

  # Register a file to be copied during the 'make install' phase.
  def install(src)
    buf = {
        :sources => nil,
        :dest => nil,
        :directory? => false,
        :group => nil,
        :user => nil,
        :mode => '0755',
    }
#TODO: check for leading '/': raise ArgumentError, 'absolute path is required' unless src[:dest].index(0) == '/'
    raise ArgumentError, ':dest is require' if src[:dest].nil?
    raise ArgumentError, 'Cannot specify both directory and sources' \
       if buf[:directory] == true and not buf[:sources].nil
    @items.push buf.merge(src)
  end

  def to_make
    m = Makefile.new

    # Add variables
    tmp = { 
        'PACKAGE' => @project.id,
        'PKGINCLUDEDIR' => '$(INCLUDEDIR)/$(PACKAGE)',
        'PKGDATADIR' => '$(DATADIR)/$(PACKAGE)',
        'PKGLIBDIR' => '$(LIBDIR)/$(PACKAGE)',
    }
    tmp['INSTALL'] = @path unless @path.nil?
    @dir.each do |k,v|
      k = (k == 'exec-prefix') ? 'EPREFIX' : k.upcase
      tmp[k] = v
    end
    tmp.each { |k,v| m.define_variable(k, '=', v) }

    # Add 'make install' rules
    @items.each do |i| 
      m.add_rule('install', install_command(i)) 
      m.add_rule('uninstall', uninstall_command(i)) 
    end

    return m
  end

  private

  # Translate an @item into the equivalent shell command(s)
  def install_command(h)
    res = []

    if Platform.is_windows?
      throw 'FIXME'
    else
      res.push '$(INSTALL)'
      res.push '-d' if h[:directory]
      res.push('-m', h[:mode]) if h[:mode]
      res.push('-o', h[:owner]) if h[:owner]
      res.push('-g', h[:group]) if h[:group]
      res.push h[:sources] if h[:sources]
      res.push '$(DESTDIR)' + h[:dest]
    end

    res.join(' ')
  end

  # Translate an @item into the equivalent uninstallation shell command(s)
  def uninstall_command(h)
    res = []

    if Platform.is_windows?
      throw 'FIXME'
    else
      unless h[:sources]
        res.push 'rmdir', '$(DESTDIR)' + h[:dest]
      else
        res.push 'rm', '-f', h[:sources].map { |x| '$(DESTDIR)' + h[:dest] + '/' + x }
      end
    end

    res.join(' ')
  end

  def search()
    [ ENV['INSTALL'], '/usr/ucb/install', '/usr/bin/install' ].each do |x|
        if !x.nil? and File.exists?(x)
         return x
        end
    end
  end

end
