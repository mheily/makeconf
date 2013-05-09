# A packager produces a package in the preferred OS format (e.g. RPM, DEB)
class Packager

  attr_reader :makefile

  def initialize(project)
    @project = project
    @specfile = nil                 # RPM spec file
    @makefile = Makefile.new
  end

  # Add a native package definition file (RPM spec file, etc.)
  def add(f)
    raise 'Unsupported file format' unless f =~ /\.spec$/
    @specfile = f
    @makefile.distribute f
  end

  def finalize
    make_rpm_spec if @specfile.nil?

    # Make a copy of the specfile that we can tweak later on
    specfile_copy = "rpm/SPECS/#{@project.id}.spec"

    @makefile.add_target(
            'package',
            ['clean', @project.distfile],
     		['rm -rf rpm *.rpm',
             'mkdir -p rpm/BUILD rpm/RPMS rpm/SOURCES rpm/SPECS rpm/SRPMS',
             'mkdir -p rpm/RPMS/`uname -m`',
		     "cp #{@project.distfile} rpm/SOURCES",
		     "cp #{@specfile} #{specfile_copy}",
             "perl -pi -e 's/^Version:.*/Version: #{@project.version}/' #{specfile_copy}",
  		     'rpmbuild --define "_topdir `pwd`/rpm" -bs ' + specfile_copy,
             'rpmbuild --define "_topdir `pwd`/rpm" -bb ' + specfile_copy,
             'mv ./rpm/SRPMS/* ./rpm/RPMS/*/*.rpm .',
      		 'rm -rf rpm',
     		])
    @makefile.add_rule('clean', Platform.rm('*.rpm')) # FIXME: wildcard is bad
  end

  # Generate an RPM spec file
  def make_rpm_spec
    @specfile = 'rpm.spec'
    puts 'creating rpm.spec'
    File.unlink('rpm.spec') if File.exist?('rpm.spec')
    f = File.open('rpm.spec', 'w')
    f.puts <<EOF
# DO NOT EDIT -- automatically generated by ./configure
Name:       #{@project.id}
Summary:    #{@project.summary}
Version:    #{@project.version}
Release:    1
License:    #{@project.license}
Vendor:     #{@project.author}
Group:      System Environment/Libraries
Source0:    %{name}-%version.tar.gz

%description
#{@project.description}

%prep
#%setup -q -n #{@project.id}-#{@project.version}
%setup

%build
./configure --prefix=/usr --disable-static
make

%install
make DESTDIR=%{buildroot} install

%clean
[ %{buildroot} != "/" ] && rm -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root)

#{ @project.installer.package_manifest }

%changelog
* Thu Jan 01 2011 Some Person <nobody@nobody.invalid> - #{@project.version}-1
- automatically generated spec file
EOF
  f.close()
  @makefile.add_rule('distclean', Platform.rm('rpm.spec'))
  end
end
