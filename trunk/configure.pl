#!/usr/bin/env perl
#
# Copyright (c) 2009-2011 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# Platform-specific functions
#
package makeconf::platform;

sub rm {
    die 'at least one filename is required' unless $_[0];
    my $cmd = 'rm -f';
    if ($^O eq 'MSWin32') {
         $cmd = 'del /F';
     }
     return $cmd . ' ' . join(' ', @_);
}

1;

#
# The compiler used to build the project
#
package makeconf::compiler;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use File::Temp qw(tempfile);

sub new {
    my ($class,$path) = @_;
    my $self = +{};
    bless($self, $class);
    $self->{path} = $path;

    # Load default values
    my %default = (
            cflags => '',
            ldflags => '',
            ldadd => '',
            verbose => 0,
            );
    foreach (keys %default) {
        $self->{$_} = $default{$_} unless exists $self->{$_};
        confess "$_ is required" unless defined $self->{$_};
    }

    # Check what features the compiler supports
    #
    $self->{features} = +{};
    # FIXME: breaks on SunOS
    #print "checking if the compiler supports the -combine option.. ";
    #my $code = "int main() {}\n";
    #$sym{cc_features}->{combine} = yesno(compile($code, cflags => '-combine'));

    return $self;
}

# Return the complete command line for compiling a target
#
sub command {
    my $self = shift;
    my %opt = @_;
    my @res = ($self->{path});

    push @res, $opt{cflags};
    push @res, gcc_ldflags($opt{ldflags});
    push @res, @{$opt{sources}};
    push @res, $opt{ldadd};

    return join(' ', @res);
}

# Compile a test program
#
sub compile {
    my $self = shift;
    my $code = shift || die;
    my %opt = @_;
    $opt{cflags} ||= $self->{cflags};
    $opt{cc} ||= $self->{path};

    my ($fh, $filename) = tempfile('mcXXXXXXXXXX', 
            SUFFIX => '.c',
            UNLINK => 1,
            );
    print $fh $code or die $!;
    close($fh) or die $!;

    # Write the output to a temporary ".bin" file
    my $ofile = $filename;
    $ofile =~ s/\.c$/\.bin/;

    my $cmd = "$opt{cc} -o $ofile $opt{cflags} $filename";
    if ($self->{verbose} > 1) {
        print "\ncompiling with '$cmd`:\n" . 
              ('-' x 72) . "\n" . 
              $code . "\n" .
              ('-' x 72) . "\n"; 
    } else {
        if ($^O eq 'MSWin32') {
            $cmd .= " >NUL 2>NUL";
        } else {
            $cmd .= " >/dev/null 2>&1";
        }
    }
    system $cmd;
    my $rc = $?;
    unlink $ofile;
    if ($^O eq 'MSWin32') {
        my $objfile = $filename;
        $objfile =~ s/\.c$/\.obj/;
        unlink $objfile;
    }
    if ($rc == -1) {
        die "failed to execute: $!\n";
    } elsif ($rc & 127) {
        die "child died with signal %d, %s coredump\n",
            ($rc & 127),  ($rc & 128) ? 'with' : 'without';
    } else {
        my $retval = $rc >> 8;
        print "exit status = $retval\n" if $self->{verbose} > 1;
        return ($retval == 0 ? 1 : 0);
    }
}

# Translate the linker flags into GCC-style -W,<flag>=<value>
#
sub gcc_ldflags {
    my (@tok) = split / /, $_[0];
    my @res;

    while (@tok) {
        my $opt = shift @tok;
        if ($opt eq '-L') {
            my $path = shift @tok;
            push @res, "-L $path";
        } elsif ($opt =~ /^-(rpath)$/) {
            my $val = shift @tok;
            push @res, "-Wl,$opt=$val";
        } else {
            die "unsupported linker option: $opt";
        }
    }
    return join(' ', @res);
}

1;

#---------------------------------------------------------------------#

#
# A single executable target to be built
#
package makeconf::target::executable;

use strict;
use warnings;

use Carp;
use Data::Dumper;

sub new {
    my ($class,$id,$self) = @_;
    $self->{id} = $id;
    bless($self, $class);

    # Load default values
    my %default = (
            cc => undef,
            cflags => '',
            ldflags => '',
            ldadd => '',
            sources => [],
            headers => [],
            depends => [],
            );
    foreach (keys %default) {
        $self->{$_} = $default{$_} unless exists $self->{$_};
        confess "$_ is required" unless defined $self->{$_};
    }

    return $self;
}

sub make {
    my ($self,$mf) = @_;

    my @deps = (@{ $self->{sources} }, @{ $self->{depends} });
    my $binfile = $self->{id};
    my $cflags = $self->{cflags};
    if ($^O eq 'MSWin32') {
        $binfile .= '.exe';
        $cflags = '/Fe$@';
    } else {
        $cflags = '-o $@ ' . $cflags;
    }
    $mf->add_target($binfile, \@deps, [
            $self->{cc}->command(
                cflags  => $cflags,
                ldflags => $self->{ldflags}, 
                sources => $self->{sources},
                ldadd => $self->{ldadd})]);

    $mf->add_distributable($self->{sources});
    $mf->add_dependency('all', $binfile);
    $mf->add_rule('clean', makeconf::platform::rm($binfile));
    $mf->add_deliverable($binfile, '$(BINDIR)'); #XXX-make relocatable
}

1;

#---------------------------------------------------------------------#
#
# A single library target to be built
#
package makeconf::target::library;

use strict;
use warnings;

use Data::Dumper;

sub new {
    my ($class,$id,$self) = @_;
    $self->{id} = $id;
    bless($self, $class);

    # Load default values
    my %default = (
            'abi_major' => '0',
            'abi_minor' => '0',
            'enable_shared' => 1,
            'enable_static' => 1,
            'cflags' => '', # TODO: pull from project
            'ldflags' => '', # TODO: pull from project
            'ldadd' => '', # TODO: pull from project
            'sources' => [],
            'headers' => [],
            );
    foreach (keys %default) {
        $self->{$_} = $default{$_} unless exists $self->{$_};
    }

    return $self;
}

sub make_shared_library {
    my ($self,$mf) = @_;

    my $sofile = "$self->{id}.so";
    my $suffix = $self->{abi_major} . '.' . $self->{abi_minor};
    $mf->add_target($sofile, $self->{sources}, [
            join(' ', '$(CC)', '-o $@', $self->{cflags}, '-shared',
                '-fPIC', '-fwhole-program',
                '$(LDFLAGS)', @{$self->{sources}}, $self->{ldadd})]);

    $mf->add_dependency('all', $sofile);
    $mf->add_rule('clean', makeconf::platform::rm($sofile));
    $mf->add_deliverable($sofile, "\$(LIBDIR)/$sofile.$suffix", 1);
        
    # Create symlinks from libfoo.so.0.0 to libfoo.so.0 and libfoo.so
    # This allows multiple versions of a library to be installed 
    # without clobbering each other
    #
    # TODO: check before clobbering symlinks
    foreach ("$self->{id}.so.$self->{abi_major}", "$self->{id}.so") {
        $mf->add_rule('install', "\$(LN) -sf $sofile.$suffix \$(DESTDIR)\$(LIBDIR)/$_");
        $mf->add_rule('uninstall', makeconf::platform::rm("\$(DESTDIR)\$(LIBDIR)/$_"));
    }
}

sub make_static_library {
    my ($self,$mf) = @_;

    my $afile = $self->{id} . '.a';

    my (@rules,@objs);
    foreach my $src (@{ $self->{sources} }) {
        my $obj = $src;
        $obj =~ s/\.c$/.o/;
        push @objs, $obj;
        push @rules, join(' ', '$(CC)', '-c', "-o $obj", $self->{cflags},
                '$(LDFLAGS)', $src);
        $mf->add_rule('clean', makeconf::platform::rm($obj));
    }
    push @rules, "ar rcs $afile " . join(' ', @objs);

    $mf->add_target($afile, $self->{sources}, \@rules);
    $mf->add_dependency('all', $afile);
    $mf->add_rule('clean', makeconf::platform::rm($afile));
#TODO: add a configuration flag to make this installable
#$mf->add_deliverable($afile, '$(LIBDIR)');
}

sub make {
    my ($self,$mf) = @_;
    $self->make_shared_library($mf) if $self->{enable_shared};
    $self->make_static_library($mf) if $self->{enable_static};
    $mf->add_distributable($self->{sources});

    # Install headers
    foreach (@{ $self->{headers} }) {
        $mf->add_deliverable($_, '$(INCLUDEDIR)');
    }
    $mf->add_distributable($self->{headers});
}

1;

#---------------------------------------------------------------------#

#
# Parse the configuration file
#
package makeconf::config;

use Carp;
use Getopt::Long;
use YAML ();
use Data::Dumper;

use strict;
use warnings;

my $version = '$Revision: 23 $';
$version =~ s/[^\d]//g;

# ------------------------- Public methods ------------------- #

sub new {
    my $class = shift;
    my $path = shift || die;
    my $self = {
        verbose => 0,
        conffile => $path,

        # Compilation options and helper program paths
        cc => $ENV{CC} || which(qw(cc gcc clang)),
        cflags => $ENV{CFLAGS} || '',
        ldflags => $ENV{LDFLAGS} || '',
        ldadd => $ENV{LDADD} || '',
        tar => $ENV{TAR} || which(qw(tar)),
        ar => $ENV{AR} || which(qw(ar gar)),
        ln => $ENV{LN} || which('ln'),
        install => $ENV{INSTALL} || which(qw(install)),

        # Installation paths
        prefix => '/usr/local',
        bindir => '$(PREFIX)/bin',
        sbindir => '$(PREFIX)/sbin',
        libdir => '$(PREFIX)/lib', # XXX-FIXME - add lib64 for Fedora
        includedir => '$(PREFIX)/include',
        mandir => '$(PREFIX)/share/man',

        # Private variables
        symbol => +{},
        header => +{},
        ast => undef,
    };
    bless($self, $class);

    if ($^O eq 'MSWin32') {
       $self->get_msvc_info(); 
    }

    if (not -e $path) {
        die "$path: file not found";
    }

    $self->{ast} = YAML::LoadFile('config.yaml'),
    $self->{ast}->{headers} ||= [];
#    warn Dumper($self);
    makeconf::project->new(%{ $self->{ast} });

    $self->parse_argv();
    $self->check_target();
    $self->check_compiler();
    $self->check_archiver();
    $self->check_install();
    $self->check_header(@{ $self->{ast}->{check_header} });
    foreach (sort keys %{ $self->{ast}->{check_symbol} }) {
        $self->check_symbol($_, $self->{ast}->{check_symbol}->{$_});
    }

    # Kludge: pull things out of the AST for use by export_to_c()
    $self->{version} = $self->{ast}->{version};
    $self->{project} = $self->{ast}->{project};

    # Finalize all strings by expanding macros
    foreach my $p (makeconf::project::projects()) {
        $p->finalize();
    }

    return $self;
}

# Get the location of Microsoft Visual Studio paths
#
sub get_msvc_info {
    my $self = shift || die;

    my @tmp = glob($ENV{'SYSTEMDRIVE'} . '/Program\ Files/Microsoft\ Visual\ Studio*');
    die 'Cannot find Visual Studio' unless @tmp;
    die 'Found multiple versions of Visual Studio' if $tmp[1];
    my $msvc = $tmp[0];
    $msvc =~ s/ /\\ /g;

    $self->{cc} = 'cl.exe';
    $self->{ar} = 'cl.exe'; # TODO, this is probably not needed
}

sub get {
    my $self = shift;
    my $key = shift || die;
    die "configuration key '$key' does not exist" 
        unless exists $self->{ast}->{$key};
    return $self->{ast}->{$key};
}

sub export_to_c {
    my $self = shift;
    my @c_exports = (qw(version target api cflags));

    print "Creating config.h\n";
    open (my $fd, ">config.h") or die "open of config.h: $!";
    my @cpp_define = map { 
                    die "missing symbol: $_" unless exists $self->{$_};
                    die "undefined symbol: $_" unless defined $self->{$_};
                    '#define ' . uc($_) . ' ' . $self->{$_} . "\n";
                    } @c_exports;
    print $fd "/* AUTOMATICALLY GENERATED -- DO NOT EDIT */\n", @cpp_define or die;
    foreach my $key (keys %{$self->{header}}) {
        my $header = uc $key;
        $header =~ tr/[.\/\-]/_/;
        if ($self->{header}->{$key}) {
            print $fd "#define HAVE_$header 1\n";
        } else {
            print $fd "#undef  HAVE_$header\n";
        }
    }
    close($fd) or die;
}

sub make_pkgconfig {
    my $self = shift;
    my $mf = shift || die;
    my %pc;

    if ($self->{ast}->{pkgconfig}) {
        %pc = %{ $self->{ast}->{pkgconfig} };
    }

    # Fill in default values
    my %default = (
            'name' => $self->get('project'),
            'version' => $self->get('version'),
            'description' => 'FIXME',
            'requires' => '',
            'conflicts' => '',
            'url' => undef,
            'libs' => undef,
            'libs.private' => undef,
            'cflags' => undef,
            );
    while (my ($key,$val) = each %default) {
        $pc{$key} = $val unless exists $pc{$key} and defined $pc{$key};
    }

    my $ofn = $self->{ast}->{project} . '.pc';
    open (my $fd, '>', $ofn) or die "$ofn: $!";
    #TODO: define variables like $prefix
    print $fd "\n";
    foreach my $key (qw(Name Description Version URL Requires Conflicts 
                        Libs Libs.private Cflags)) {
        my $lckey = lc $key;
        die "missing $lckey" unless exists $pc{$lckey};
        my $val = $pc{$lckey};
        next unless defined $val;
        print $fd "$key: $val\n";
    }
    close $fd or die;

    $mf->add_rule('clean', makeconf::platform::rm($ofn));
}

sub make_binaries {
    my $self = shift;
    my $mf = shift || die;

    while (my ($key, $ent) = each %{ $self->{ast}->{binaries} }) {
        $ent->{cc} ||= $self->{cc};
        my $bin = makeconf::target::executable->new($key,$ent) or die;
        $bin->make($mf);
    }
}

sub make_libraries {
    my $self = shift;
    my $mf = shift || die;

    while (my ($key, $ent) = each %{ $self->{ast}->{libraries} }) {
        my $lib = makeconf::target::library->new($key,$ent) or die;
        $lib->make($mf);
    }
}

sub make_dist {
    my $self = shift;
    my $mf = shift || die;
    my $distname = $self->{project} . '-' . $self->{version};

    $mf->prepend_rule('dist', [
            "rm -f $distname.tar.gz",
            "rm -rf $distname",
            "mkdir $distname",
            "\$(INSTALL) -m 755 configure $distname",
            "\$(INSTALL) -m 644 config.yaml $distname",
            ]);

    # Automatically include the required GNU files, if they exist
    my @inc;
    foreach (qw(INSTALL NEWS README AUTHORS ChangeLog COPYING)) {
        push @inc, $_ if -f $_;
    }
    $mf->add_rule('dist', "\$(INSTALL) -m 644 ".join(' ', @inc). " $distname") if @inc;

    # Add the commands to generate the tarball
    $mf->add_rule('dist', [
            "tar cf $distname.tar $distname",
            "gzip $distname.tar",
            "rm -rf $distname",
            ]);
}

sub export_to_make {
    my $self = shift;

    # Symbols to be exported to config.mk
    #
    my @make_exports= (qw(version target api  
              prefix bindir sbindir libdir includedir mandir 
              cflags ldflags ldadd
              cc ln ar tar install));
    #FIXME: abi_major abi_minor abi_version diff mans headers extra_dist subdirs 

    my $mf = makeconf::makefile->new(distdir => $self->{project} . '-' . $self->{version});

    foreach (@make_exports) {
        die "missing symbol: $_" unless exists $self->{$_};
        my $val = $self->{$_};
        $val = $self->{cc}->{path} if $_ eq 'cc';
        $mf->define_variable(uc($_), '=', $val);
    }
    $mf->add_target('all', [], []);
    $mf->add_target('clean', [], []);
    $mf->add_target('dist', ['all'], []);
    $mf->add_target('distclean', ['clean'], [makeconf::platform::rm(qw(Makefile config.h))]);
    $mf->add_target('check', ['all'], []);
    $mf->add_target('install', ['all'], []);
    $mf->add_target('uninstall', [], []);
    $mf->add_target('package', ['all'], []);

    $self->make_libraries($mf);
    $self->make_binaries($mf);
    $self->make_pkgconfig($mf);
#TODO: $self->make_install($mf);
#TODO: $self->make_tests($mf);
    $self->make_dist($mf);
#TODO: $self->make_package($mf);
#TODO: $self->make_custom($mf);  #custom user-defined targets

    print "writing Makefile\n";
    open (my $fd, ">Makefile") or die "open of Makefile: $!";
    print $fd $mf->render or die;
    close($fd) or die;
    return;

     #-----------deadwood below -----------


    # Generate the 'install' target
    #
#print $fd "\ninstall: ", join(" ", @all), "\n";
#    foreach my $p (makeconf::project::projects()) {
#        print $fd join("\n", $p->{install}->makefile_rules()), "\n";
#    }

    # Generate the 'package' target
    #
    print $fd "\npackage:\n\t./configure --mc-make-package\n";

    # Generate the 'dist' target
    #
    print $fd "\ndist:\n";
    foreach my $p (makeconf::project::projects()) {
        my $name = $p->{project}; # ????
        my @dist;
        my $prepend = $name . '-' . $p->{version};
        push @dist, map { $p->{_basedir} . $_ } 
           ('configure', 'Makefile', 'config.inc', @{ $p->{extra_dist} });
        foreach my $t (values %{$p->{targets}}) {
            next unless exists $t->{sources};
            push @dist, map { $p->{_basedir} . $_ } @{ $t->{sources} }; 
        }
#FIXME: support a 'scripts' option?
#push @dist, map { $p->{_basedir} . $_ } keys %{$p->{scripts}};
        while (@{ $p->{data} }) {
            my $target = shift @{ $p->{data} };
            my $files = shift @{ $p->{data} };
            push @dist, map { $p->{_basedir} . $_ } @{$files};
        }

# XXX-FIXME GNU TAR REQUIRED
        print $fd "\t\$(TAR) --transform 's,^,$prepend/,S' " .
                    " -c -z -f $prepend.tgz" .
                    " " . join(' ', uniq(@dist)) .
                    "\n";
    }

=pod
	mkdir $(PROGRAM)-$(VERSION)
	cp  Makefile ChangeLog configure config.inc      \
        $(MANS) $(EXTRA_DIST)   \
        $(PROGRAM)-$(VERSION)
	cp -R $(SUBDIRS) $(PROGRAM)-$(VERSION)
	rm -rf `find $(PROGRAM)-$(VERSION) -type d -name .svn -o -name .libs`
	cd $(PROGRAM)-$(VERSION) && ./configure && cd test && ./configure && cd .. && make distclean
	tar zcf $(PROGRAM)-$(VERSION).tar.gz $(PROGRAM)-$(VERSION)
	rm -rf $(PROGRAM)-$(VERSION)
=cut


    # Generate all user-defined targets
    #
    foreach my $p (makeconf::project::projects()) {
        while (my ($key,$rec) = each %{$p->{targets}}) {
            print $fd generate_make_target($key, $p, $rec);
        }
    } # each project

    close($fd) or die;
}

# ------------------------- Private methods ------------------- #

sub compile {
    my $self = shift;
    $self->{cc}->compile(@_);
}

sub parse_argv {
    my $self = shift;
    my %opt;

    GetOptions(\%opt,
        'help|h',
        'version|V',
        'verbose|v',
        'prefix=s',
        'bindir=s',
        'sbindir=s',
        'libdir=s',
        'includedir=s',
        'mandir=s',
        'mc-make-package',
        ) or exit(1);

    # Process options that trigger an action
    #
    my %dispatch = (
            help => \&print_usage,
            version => \&print_version,
            "mc-make-package" => \&make_package,
# FIXME:if [ "$id" = "generate-rpath" ] ; then
            );
    foreach (keys %dispatch) {
        next unless exists $opt{$_};
        $dispatch{$_}($opt{$_}) if exists $opt{$_};
        delete $opt{$_};
    }
    
    # FIXME-Process options that modify the symbol table
    #
#foreach my $key (keys %opt) {
#        $sym{$key} = $opt{$key};
#    }

    # Process options that modify global settings
    #
    $self->{verbose}++ if $opt{verbose};
}

sub check_target {
    my $self = shift;

    print "checking operating system type.. ";
    $self->{target} = $^O;
    $self->{api} = 'posix';
    if ($^O eq 'MSWin32') {
        $self->{target} = 'windows';
        $self->{api} = 'windows';
    }
    print "$self->{target}\n";
}

sub check_compiler {
    my $self = shift;

    print "checking for a C compiler.. $self->{cc}\n";
    die 'not found' unless $self->{cc};

    $self->{cc} = makeconf::compiler->new($self->{cc});
}

sub check_archiver {
    my $self = shift;

    print "checking for a suitable archiver.. ";
    die 'not found' unless $self->{ar};

    print "$self->{ar}\n";
}

sub check_install {
    my $self = shift;

    if ($^O eq 'MSWin32') {
        $self->{install} = 'XXX-FIXME';
    }

    print "checking for a BSD-compatible install.. ";
    # workaround for solaris:
    if (-x '/usr/ucb/install') {
            $self->{install}='/usr/ucb/install';
    }
    die "not found" unless $self->{install};

    print "$self->{install}\n";
}

sub check_header {
    my $self = shift;
    foreach my $header (@_) {
        print "checking for $header... ";
        my $code = "#include <$header>\nint main() {}\n";
        $self->{header}->{$header} = yesno($self->compile($code));
    }
}

sub check_symbol {
    my $self = shift;
    my $header = shift || die;
    my (@symbols);

    die unless @_;
    if (ref($_[0]) eq 'ARRAY') {
        (@symbols) = @{ $_[0] };
    } else { 
        (@symbols) = @_;
    }

    # Check that the header is available
    #
    $self->check_header($header) unless exists $self->{header}->{$header};

    $self->{symbol}->{$header} ||= +{};
    foreach my $symbol (@symbols) {
        print "checking $header for $symbol... ";

        if ($self->{header}->{$header} == 0) {
            print "no ($header is missing)\n";
            $self->{symbol}->{$header}->{$symbol} = 0;
            next; 
        }

        my $found = 0;

        # See if the symbol is a macro
        #
        my $code = "
            #include <$header>
            #if !defined($symbol)
            #error no
            #endif
            int main() {}\n";
        if ($self->compile($code)) {
            $found = 1;
        }

        # See if the symbol is an actual symbol
        #
        $code = "#include <$header>\nint main() { void *p; p = &$symbol; }\n";
        if (not $found and $self->compile($code)) {
            $found = 1;
        }
        $self->{symbol}->{$header}->{$symbol} = yesno($found);
    }
}

sub dump {
    confess Dumper($_[0]);
}

#----------------------- Class functions -----------------------#


# Given an array, return the unique values while preserving the original order
#
sub uniq {
    my %seen = ();
    return (grep { ! $seen{$_} ++ } @_);
}

sub yesno {
    my $x = shift;
    if (defined $x and $x ne '' and $x ne '0') {
        print "yes\n";
        return 1;
    } else {
        print "no\n";
        return 0;
    }
}

# Search the $PATH for the location of an executable
#
sub which {
    foreach my $program (@_) {
        foreach my $prefix (split /:/, $ENV{PATH}) {
            my $path = "$prefix/$program";
            return $path if -x $path;
        }
    }
    return '';
}

1;

package makeconf::macros;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $initial = shift || +{};
    my $self = {
        macros => $initial,
    };
    return bless($self, $class);
}

sub define {
    my $self = shift;
    my $key = shift || die;
    my $val = shift;

    die "multiple definition of macro '$key'" 
        if exists $self->{macros}->{$key};
    $self->{macros}->{$key} = $val;
}

sub expand {
    my $self = shift;
    my $s = shift;

    while ($s =~ /\$\{?([A-Za-z0-9_]+)\}?/) {
        my $key = $1;
        die "undefined macro '$key'" unless exists $self->{macros}->{$key};
        $s =~ s/\$\{?$key\}?/$self->{macros}->{$key}/g or die;
    }

    return $s;
}

sub expand_each {
    my $self = shift;
    for my $x (@{ $_[0] }) {
        $x = $self->expand($x);
    }
}

sub expand_keys {
    my $self = shift;
    my $h = shift;

    foreach my $key (keys %{ $h }) {
        if ($key =~ /\$/) {
            $h->{$self->expand($key)} = $h->{$key};
            delete $h->{$key};
        }
    }
}

sub finalize {
    my $self = shift;

    my %tmp = %{ $self->{macros} };
    my %fin;
    while (keys %tmp) {
        my $progress = 0;
        foreach my $key (keys %tmp) {
            my $val = $tmp{$key};
            if ($val =~ /\$\{?([A-Za-z0-9]+)\}?/) {
                my $id = $1;
                die "Macro '$key' is self-referential, which is not allowed" 
                    if $id eq $key;
                if (exists($fin{$id})) {
                    $tmp{$key} =~ s/\$\{?$id\}?/$fin{$id}/g;
                    $progress++;
                } elsif (not exists($tmp{$id})) {
                    die "Macro '$key' refers to nonexistent macro '$id'";
                }
            } else {
                $fin{$key} = $val;
                delete $tmp{$key};
                $progress++;
            }
        }
        die 'Infinite macro expansion detected' unless $progress;
    }
    $self->{macros} = \%fin;
}

1;

package makeconf::target;

use Text::ParseWords;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %x = @_;
    my $self = {
        sources => [],
        cflags => '',
        ldflags => '',
        ldadd => '',
    };
    foreach (keys %{$self}) {
        $self->{$_} = $x{$_} if exists $x{$_};
    }

    # Normalize certain values
    foreach (qw(cflags ldflags ldadd)) {
        $self->{$_} = [ parse_line(' ', 0, $self->{$_}) ];
    }

    return bless($self, $class);
}

sub print_usage {
    die 'TODO -- usage';
    exit(0);
}

sub print_version {
    print "makeconf r$version\n";
    exit(0);
}

1;

package makeconf::project;

use Text::ParseWords;
use Data::Dumper;

use strict;
use warnings;

# Project table
#
my %project;

sub projects { return values %project }

sub new {
    my $class = shift;
    my %x = @_;
    my $self = +{
        project => undef,
        version => undef,
        _basedir => '', # FIXME: support nested projects in subdirectories
        macros => +{
            'prefix' => '/usr',
            'bindir' => '$prefix/bin',
            'sbindir' => '$prefix/sbin',
            'includedir' => '$prefix/include',
            'pkgincludedir' => '$includedir/$project',
        },

        # FIXME; duplicates information in {ast}, these should be dropped
        'pkgconfig' => +{},     # information to build a pkg-config .pc file
        'package' => +{},       # information to build a RPM package manifest

        # Files to be installed in /usr/include
        headers => [],

        # Files to be installed in /usr/lib
        libraries => [],

        # Executable binaries
        binaries => [],

        targets => +{},
        tests => [],
        scripts => [],
        data => [],
        install => [],
        extra_dist => [],
        check_header => [],
        check_symbol => +{},
    };
    my $err = 0;

    foreach my $key (keys %{$self}) {
        if (exists $x{$key}) {
            $self->{$key} = $x{$key};
            delete $x{$key};
        }
    }
    foreach my $key (keys %x) {
        print "*ERROR* Unrecognized project attribute: $key\n";
        $err++;
    }
    foreach my $key (keys %{$self}) {
        unless (defined ($self->{$key})) {
            print "*ERROR* Undefined project attribute: $key\n";
            $err++;
        }
    }
    die 'Too many errors' if $err;

    die 'Project is required' unless defined $self->{project};
    die 'Duplicate project id' if exists $project{$self->{project}};
    $self->{macros}->{project} = $self->{project};

    # Generate the 'make install' targets
    my $i = makeconf::installer->new();
    foreach (@{$self->{install}}) {
        $i->parse($_);
    }
    $self->{install} = $i;

    bless($self, $class);
    $project{$self->{project}} = $self;
    return $self;
}

# Expand all macros wherever they appear within a variable
sub finalize {
    my $self = shift;

    # First, the macro table itself must be finalized
    #
    my $m = makeconf::macros->new($self->{macros});
    $m->finalize();

    $self->{install}->finalize($m);
}

1;

package makeconf::installer;

use Text::ParseWords;
use Data::Dumper;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %x = @_;
    my $self = { 
        orig => [],       # The original install(1)-compatible commands
        mkdir => [],       # Directories to create
        cp => {},         # Files to copy; keys='destination', vals=>'sources'
        mode => {},      # keys='Paths to chmod', vals='mode'
        owner => {},      # keys='Paths to chown', vals='owner'
        group => {},      # keys='Paths to chgrp', vals='group:
    };

    return bless($self, $class);
}

# Parse an install(1) compatible command line
# e.g. 'install -d -m 755 -o root -g wheel /var/foo'
#
sub parse {
    my $self = shift;
    my $line = shift || die;
    my (@tok) = parse_line(' ', 0, $line);
    my $isdir = 0;
    my $owner = undef;
    my $group = undef;
    my $mode = undef;
    my @src;
    my $dst;

    #warn Dumper(\@tok);
    push @{$self->{orig}}, $line;
    while (@tok) {
        my $x = shift @tok;
        if ($x eq '-d' or $x eq '--directory') {
            $isdir = 1;
        } elsif ($x eq '-m' or $x eq '--mode') {
            $mode = shift @tok;
        } elsif ($x eq '-g' or $x eq '--group') {
            $group = shift @tok;
        } elsif ($x eq '-o' or $x eq '--owner') {
            $owner = shift @tok;
        } elsif ($x =~ /^-/) {
            die 'Unrecognized install(1) option "$x"';
        } else {
            push @src, $x;
        }
    }
    $dst = pop @src;

    if ($isdir) {
        push @{ $self->{mkdir} }, $dst;
        $self->{owner}->{$dst} = $owner if defined $owner;
        $self->{group}->{$dst} = $group if defined $group;
        $self->{mode}->{$dst} = $mode if defined $mode;
    } else {
        foreach (@src) {
            $self->{cp}->{$dst} ||= [];
            push @{$self->{cp}->{$dst}}, $_;
            $self->{owner}->{$_} = $owner if defined $owner;
            $self->{group}->{$_} = $group if defined $group;
            $self->{mode}->{$_} = $mode if defined $mode;
        }
    }
}

sub finalize {
    my ($self, $mc) = @_;

    $mc->expand_each($self->{orig});
    $mc->expand_each($self->{mkdir});
    $mc->expand_each($self->{mkdir});
    $mc->expand_keys($self->{owner});
    $mc->expand_keys($self->{group});
    $mc->expand_keys($self->{mode});
    $mc->expand_keys($self->{cp});
}

# Generate the 'install' Makefile target
#
sub makefile_rules {
    my $self = shift;
    my @res;

    #warn Dumper($self);
#    foreach (@{$self->{orig}}) {
#        push @res, "\t" . '$(INSTALL) ' . $_;
#    }

    # Create directories
    foreach (@{$self->{mkdir}}) {
        my $mode = $self->{mode}->{$_};
        my $owner = $self->{owner}->{$_};
        my $group = $self->{group}->{$_};
        my $flags = ' ';
        $flags .= "-m $mode " if defined $mode;
        $flags .= "-o $owner " if defined $owner;
        $flags .= "-g $group " if defined $group;
        push @res, "\t" . '$(INSTALL) -d' . $flags . '$(DESTDIR)' . $_;
    }

    # Copy files
    foreach (keys %{$self->{cp}}) {
        my $mode = $self->{mode}->{$_};
        my $owner = $self->{owner}->{$_};
        my $group = $self->{group}->{$_};
        my $flags = ' ';
        $flags .= "-m $mode " if defined $mode;
        $flags .= "-o $owner " if defined $owner;
        $flags .= "-g $group " if defined $group;
        push @res, "\t" . '$(INSTALL) ' . $flags . join(' ', @{$self->{cp}->{$_}}) . ' $(DESTDIR)' . $_;
    }

    # TODO: support platforms without GNU make

    return (@res);
}

sub dump { die Dumper($_[0]); }

1;

# An object whose AST is used to generate a Makefile

package makeconf::makefile;

use Carp;
use Data::Dumper;
use File::Basename;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = {
        vars => +{},     # variable definitions (e.g., 'A=b')
        targets => +{}, # targets and associated rules
        @_,
    };
    bless($self, $class);

    return $self;
}

sub define_variable {
    my ($self, $lval, $op, $rval) = @_;
    $self->{vars}->{$lval} = [ $op, $rval ];
}

sub add_target {
    my ($self, $objs, $deps, $rules) = @_;
    confess if ref($objs) or ref($deps) ne 'ARRAY' or ref($rules) ne 'ARRAY';
    $self->{targets}->{$objs} = [ $deps, $rules ];
}

sub add_dependency {
    my ($self, $obj, $dep) = @_;
    my $ent = $self->{targets}->{$obj} || die "target $obj does not exist";
    push @{ $ent->[0] }, $dep;
}

sub add_rule {
    my ($self, $obj, $dep) = @_;
    my $ent = $self->{targets}->{$obj} || die "target $obj does not exist";
    if (ref($dep) eq 'ARRAY') {
        push @{ $ent->[1] }, @{ $dep };
    } else {
        push @{ $ent->[1] }, $dep;
    }
}

sub prepend_rule {
    my ($self, $obj, $dep) = @_;
    my $ent = $self->{targets}->{$obj} || die "target $obj does not exist";
    if (ref($dep) eq 'ARRAY') {
        unshift @{ $ent->[1] }, @{ $dep };
    } else {
        unshift @{ $ent->[1] }, $dep;
    }
}

# Add an installable file
sub add_deliverable {
    my ($self, $src, $dst, $rename) = @_;
    $self->add_rule('install', '$(INSTALL) -m 644 ' . $src . ' $(DESTDIR)' . $dst);
    if ($rename) {
        $self->add_rule('uninstall', makeconf::platform::rm("\$(DESTDIR)$dst"));
    } else {
        $self->add_rule('uninstall', makeconf::platform::rm('$(DESTDIR)' . $dst . '/' . basename($src)));
    }
}

# Add a file to the tarball generated by 'make dist'
sub add_distributable {
    my ($self, $src) = @_;
    my $mode = -x $src ? '755' : '644';
    die 'undefined distdir' unless exists $self->{distdir};
    $src = join(' ', @{ $src }) if ref($src) eq 'ARRAY';
    return unless $src;

    $self->add_rule('dist', "\$(INSTALL) -m $mode $src $self->{distdir}");
}

sub render {
    my $self = shift;
    my $s = '';

    # Define variables
    #
    foreach my $lval (sort keys %{ $self->{vars} }) {
        $s .= $lval . join('', @{$self->{vars}->{$lval}}) . "\n";
    }

    # Set the default target to be 'all'
    $s .= "\ndefault: all\n";

    # Define targets and rules
    #
    foreach my $objs (sort keys %{ $self->{targets} }) {
        $s .= "\n" . $self->render_target($objs);
    }

    return $s;
}

# ---------- Private methods ------------------

# todo: move to a utility class
# DEADWOOD - NOT used yet
sub writefile {
    my ($path, $string) = @_;
    open (my $fd, ">$path") or die "open of $path: $!";
    print $fd $string or die $!;
    close($fd) or die $!;
}

sub render_target {
    my ($self,$objs) = @_;
    my $s = '';
    my $ent = $self->{targets}->{$objs};
    $s .= $objs . ':';
    foreach (@{$ent->[0]}) {
        $s .= " $_";
    }
    $s .= "\n";
    foreach (@{$ent->[1]}) {
        $s .= "\t$_\n";
    }
    return $s;
}

1;

package main;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Cwd;
use File::Basename;
use Text::ParseWords;

use subs qw(run);


my $verbose = 1;

# Symbol table
#
my %sym = (
        project => scalar(basename cwd),
        version => '0.1',
        mailto => 'Undefined Email <null@nowhere.local>',
        header => +{},
        );

=pod
TODO:
subst_vars() {
  outfile=$1

  if [ ! -f "${outfile}.in" ] ; then
      return
  fi

  echo "Creating $outfile"
  rm -f $outfile
  sed -e "
       s,@@CWD@@,`pwd`,g;
       s,@@PROGRAM@@,$program,g;
       s,@@VERSION@@,$version,g;
       s,@@PREFIX@@,$prefix,g;
       s,@@LIBDIR@@,$libdir,g;
       s,@@INCLUDEDIR@@,$includedir,g;
       s,@@MANDIR@@,$mandir,g;
       s,@@LIBDEPENDS@@,$libdepends,g;
       s,@@PKG_SUMMARY@@,$pkg_summary,g;
       s,@@RPM_DATE@@,`date +'%a %b %d %Y'`,g;
       s,@@PKG_DESCRIPTION@@,$pkg_description,g;
       s,@@LICENSE@@,$license,g;
       s,@@AUTHOR@@,$author,g;
       " < ${outfile}.in > $outfile
  chmod 400 $outfile
}
=cut

sub dbg {
    my $s = shift;

    if ($verbose > 1) {
        $s = Dumper($s) if ref($s);
        print $s, "\n";
    }
}

# Translate linker options from GCC syntax to the local linker syntax
#
sub convert_ldflags {
    my (@token) = @_;
    my @res;
    
    dbg(\@token);
    while (@token) {
        my $x = shift @token;
        if ($x eq '-rpath') {
            my $y = shift @token;
            if ($sym{target} eq 'solaris') {
                $x = "-R $y";
            } else {
                $x = "-Wl,-rpath,$y";
            }
        } elsif ($x eq '-soname') {
            my $y = shift @token;
            if ($sym{target} eq 'solaris') {
                $x = "-h $y";
            } else {
                $x = "-Wl,-rpath,$y";
            }
        } elsif ($x eq '-export-dynamic') {
            if ($sym{target} eq 'solaris') {
                undex $x;  # WORKAROUND
            } else {
                $x = "-Wl,-export-dynamic";
            }
        } elsif ($x =~ /^-L.*/) {
            # NOOP
        } elsif ($x =~ /^-/) {
            confess "Unrecognized linker option '$x'";
        }

        push @res, $x if defined $x;
    }

    # Workaround: Solaris 10 gcc links with 32-bit libraries in /usr/sfw/lib
    #             but we should be 64-bit instead.
    #
    if ($sym{target} eq 'solaris') {
        push @res, '-m64', '-R /usr/sfw/lib/amd64';
    }

    return (@res);
}

sub generate_make_target {
    my ($output,$proj,$rec) = @_;

    # A target without sources is probably a script
    return unless exists $rec->{sources};

    # Determine the target type
    # 
    my $type = 'binary';
    $type = 'library' if $output =~ /\.so(\.[0-9]+)?(\.[0-9]+)?$/;
    $type = 'library' if $output =~ /\.dll$/;

    # Generate the dependency list
    #
    my (@depends) = @{ $rec->{sources} };
    push @depends, @{ $rec->{depends} } if exists $rec->{depends};

    # Generate the compiler flags
    #
    my @cflags = ('$(CFLAGS)', @{$proj->{cflags}}, @{$rec->{cflags}});
    unshift @cflags, '-shared', '-fpic' if $type eq 'library';
    #TODO: make this optional
    #unshift @cflags, '-combine', '-fwhole-program'
    #    if $sym{cc_features}->{combine};

    # Generate the linker flags
    #
    my @ldflags = ('$(LDFLAGS)', @{$proj->{ldflags}}, @{$rec->{ldflags}});
    unshift @ldflags, '-export-dynamic', '-soname', $output
        if $type eq 'library';
    (@ldflags) = convert_ldflags(@ldflags);

    # Generate the additional library list
    # FIXME-changed to ldadd, this is broken
    my (@libs) = ('$(LIBS)');
    push @libs, $proj->{libs} if exists $proj->{libs};
    if (exists $rec->{libs}) {
        push @libs, ref($rec->{libs}) ? @{ $rec->{libs} } : $rec->{libs};
    }

    return  "\n" .
            "$output: " . join(' ', @depends) . "\n" .
            "\t\$(CC) -o $output " .
            join(' ', @cflags, @ldflags, @{ $rec->{sources} }, @libs) .
            "\n";
}


sub make_package {

    # Debian
    if (-x '/usr/bin/dpkg') {
        system "rm -rf debian/";
        mkdir "debian"                              or die;
        mkdir "debian/source"                       or die;
        writefile("debian/source/format", "3.0 (quilt)\n");
        writefile("debian/compat", "7\n");
        writefile("debian/changelog", "$sym{project} ($sym{version}-1) unstable; urgency=low\n\n  * Automatically generated ChangeLog entry\n\n -- $sym{mailto}  Mon, 05 Apr 2010 23:00:34 -0400\n");
        writefile("debian/control", "Source: $sym{project}
Priority: extra
Maintainer: $sym{mailto}
Build-Depends: debhelper (>= 7.0.50~)
Standards-Version: 3.8.4
Section: libs

Package: $sym{project}
Section: libdevel
Architecture: any
Depends: \${misc:Depends}
Description: TODO short description
 TODO long description
");
        writefile("debian/copyright", "TODO");
        writefile("debian/$sym{project}.install", "*\n") if 0; #FIXME: list each file
        writefile("debian/rules", join("\n",
                    "#!/usr/bin/make -f",
                    "",
                    "override_dh_auto_configure:",
                    "\t./configure --prefix=/usr",
                    "",
                    "\%:",
                    "\tdh \$@") . "\n");
        my $tardir = "$sym{project}-$sym{version}";
        mkdir "debian/$tardir" or die;
        system "pwd; cp -pR * debian/$tardir";
        run "cd debian ; tar zcf ../../$sym{project}_$sym{version}.orig.tar.gz $tardir";
        run("rm -rf debian/$tardir");
        run("dpkg-buildpackage -uc -us");
        run "rm ../$sym{project}_$sym{version}*.changes";
        run "rm ../$sym{project}_$sym{version}*.debian.tar.gz";
        run "rm ../$sym{project}_$sym{version}*.orig.tar.gz";
        run "rm ../$sym{project}_$sym{version}*.dsc";
        run "mv ../$sym{project}_$sym{version}*.deb .";
    } else {
        die "Unable to determine the native package format";
    }
}

sub writefile {
    my ($path, $string) = @_;
    open (my $fd, ">$path") or die "open of $path: $!";
    print $fd $string or die $!;
    close($fd) or die $!;
}

sub run {
    my ($command) = @_;
    system $command;
    die "command failed: '$command'" if $?;
}

#######################################################################
#
#                           MAIN()
#
#######################################################################

my $cfg = makeconf::config->new('config.yaml');
#$cfg->dump;

# TODO:
#subst_vars "$program.pc"
#subst_vars "$program.la"
#if [ "$target" = "linux" ] ; then
#  subst_vars "rpm.spec"
#fi

$cfg->export_to_c();
$cfg->export_to_make();