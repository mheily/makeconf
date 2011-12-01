# A Makefile is a collection of targets and rules used to build software.
#
class Makefile
  
  # Object constructor.
  def initialize
    @vars = {}
    @targets = {}
    @mkdir_list = []   # all directories that have been created so far

    %w[all check clean distclean install uninstall distdir].each do |x|
        add_target(x)
    end
  end

  # Add rules and targets used in the top-level Makefile
  def toplevel_init
    add_target('dist', ['clean', '$(DISTFILE)'], [])

    # Prepare the destination tree for 'make install'
    @targets['install'].add_rule('test -e $(DESTDIR)')

    # Distribute some standard files with 'make distdir'
    ['config.yaml', 'configure'].each { |f| distribute(f) }

    # Distribute makeconf.rb
    if File.exists?('makeconf.rb')
        distribute('makeconf.rb')
    elsif File.exists?('makeconf/makeconf.rb')
        distribute('makeconf/makeconf.rb')
    else
        throw 'Unable to locate makeconf.rb'
    end
  end

  # Define a variable within the Makefile
  def define_variable(lval,op,rval)
    throw "invalid arguments" if lval.nil? or op.nil? 
    throw "variable `#{lval}' is undefined" if rval.nil?
    @vars[lval] = [ op, rval ]
  end

  def merge!(src)
    throw 'invalid argument' unless src.is_a?(Makefile)
    @vars.merge!(src.vars)
    @mkdir_list.push(src.mkdir_list) 
    src.targets.each do |k,v|
      if targets.has_key?(k)
         targets[k].merge!(v)
      else
         targets[k] = (v)
      end
    end
  end

  def add_target(object,depends = [], rules = [])
    @targets[object] = Target.new(object,depends,rules)
  end

  def add_rule(target, rule)
    add_target(target, [], []) unless @targets.has_key? target
    @targets[target].add_rule(rule)
  end

  # Add a file to the tarball during 'make dist'
  def distribute(path)
    # FIXME: support Windows backslashery
    if path =~ /\//
       dst = '$(distdir)/' + File.dirname(path)
       @targets['distdir'].mkdir(dst)
       @targets['distdir'].cp(path, dst)
    else
       @targets['distdir'].cp(path, '$(distdir)')
    end
  end

  # Add a file to be removed during 'make clean'
  def clean(path)
    add_rule('clean', Platform.rm(path))
  end

  def add_dependency(target,depends)
    add_target(target, [depends], []) unless @targets.has_key? target
    @targets[target].add_dependency(depends)
  end

  # Add a file to be installed during 'make install'
  def install(src,dst,opt = {})
    rename = opt.has_key?('rename') ? opt['rename'] : false
    mode = opt.has_key?('mode') ? opt['mode'] : nil
    mkdir = opt.has_key?('mkdir') ? opt['mkdir'] : true

    # Determine the default mode based on the execute bit
    if mode.nil?
      mode = File.executable?(src) ? '755' : '644'
    end

    # Automatically create the destination directory, if needed
    if mkdir and not @mkdir_list.include?(dst)
       add_rule('install', "test -e $(DESTDIR)#{dst} || $(INSTALL) -d -m 755 $(DESTDIR)#{dst}")
       @mkdir_list.push(dst)
    end

    add_rule('install', "$(INSTALL) -m #{mode} #{src} $(DESTDIR)#{dst}")
    add_rule('uninstall', Platform.rm("$(DESTDIR)#{dst}/#{File.basename(src)}"))

    # FIXME: broken
#   if (rename) 
#      add_rule('uninstall', Platform.rm('$(DESTDIR)' + dst))
#    else 
#      raise "FIXME"
##add_rule('uninstall', Platform.rm('$(DESTDIR)' + $dst + '/' . basename($src)));
#    end 
  end

  def add_distributable(src)
    mode = '755' #TODO: test -x src, use 644 
    #FIXME:
    # add_rule('dist', "$(INSTALL) -m %{mode} %{src} %{self.distdir}")
  end

  def make_dist(project,version)
    distdir = project + '-' + version
    # XXX-FIXME this should come from the Project
    distfile = project + '-' + version + '.tar.gz'
    tg = Target.new(distfile)
    tg.add_rule(Platform.rmdir(distdir))
    tg.add_rule("mkdir " + distdir)
    tg.add_rule('$(MAKE) distdir distdir=' + distdir)
    if Platform.is_windows? 
       require 'zip/zip'
# FIXME - Not implemented yet

    else
       tg.add_rule("rm -rf #{distdir}.tar #{distdir}.tar.gz")
       tg.add_rule("tar cf #{distdir}.tar #{distdir}")
       tg.add_rule("gzip #{distdir}.tar")
       tg.add_rule("rm -rf #{distdir}")
       clean("#{distdir}.tar.gz")
    end
    @targets[distfile] = tg
  end

  def to_s
    res = ''
    @vars.sort.each { |x,y| res += x + y[0] + y[1] + "\n" }
    res += "\n\n"
    res += "default: all\n"
#XXX   require 'pp'
#XXX    puts '---------'
#XXX   pp @targets
    targets.each { |x,y| throw "#{x} is broken" unless y.is_a? Target }
    @targets.sort.each { |x,y| res += y.to_s }
    res
  end

  protected

  attr_reader :vars, :targets, :mkdir_list
end
