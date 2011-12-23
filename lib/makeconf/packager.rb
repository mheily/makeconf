# A packager produces a package in the preferred OS format (e.g. RPM, DEB)
class Packager

  attr_reader :makefile

  def initialize(project)
    @project = project
    @makefile = Makefile.new
  end

  def finalize
    make_rpm_spec
    @makefile.add_target(
            'package',
            ['clean', @project.distfile],
     		['rm -rf rpm *.rpm',
             'mkdir -p rpm/BUILD rpm/RPMS rpm/SOURCES rpm/SPECS rpm/SRPMS',
             'mkdir -p rpm/RPMS/i386 rpm/RPMS/x86_64',
		     "cp #{@project.distfile} rpm/SOURCES",
  		     'rpmbuild --define "_topdir ./rpm" -bs rpm.spec',
  	   	     'mv ./rpm/SRPMS/* .',
      		 'rm -rf rpm',
     		])
  end

  # Generate an RPM spec file
  def make_rpm_spec
    puts 'creating rpm.spec'
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

%package devel
Summary: Header files, libraries and development documentation for %{name}
Group: Development/Libraries
Requires: %{name} = %{version}-%{release}

%description devel
This package contains the header files, static libraries and development
documentation for %{name}. If you like to develop programs using %{name},
you will need to install %{name}-devel.

%prep
%setup -q -n PROGRAM-VERSION

%build
./configure --prefix=/usr
make

%install
make DESTDIR=%{buildroot} install

%clean
[ %{buildroot} != "/" ] && rm -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root)

/usr/lib/*.so.*

%files devel
%defattr(-,root,root)

/usr/lib/*.so
/usr/include/*
/usr/share/man/man3/*

%changelog
* Thu Jan 01 2011 Some Person <nobody@nobody.invalid> - #{@project.version}-1
- automatically generated spec file
EOF
  f.close()
  end
end
