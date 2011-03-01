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

use strict;
use warnings;

use Data::Dumper;
use Cwd;
use File::Basename;
use File::Temp qw(tempfile);
use Getopt::Long;

my $version = '$Revision: 23 $';
$version =~ s/[^\d]//g;

my $verbose = 1;

# Project table
#
my %project;

# Symbol table
#
my %sym = (
        project => undef,
        version => '0.1',
        cflags => $ENV{CFLAGS} || '',
        ldflags => $ENV{LDFLAGS} || '',
        libs => $ENV{LIBS} || '',
        prefix => '/usr/local',
        bindir => '$(PREFIX)/bin',
        sbindir => '$(PREFIX)/sbin',
        libdir => '$(PREFIX)/lib',
        includedir => '$(PREFIX)/include',
        mandir => '$(PREFIX)/share/man',
        ar => $ENV{AR} || which(qw(ar gar)),
        cc => $ENV{CC} || which(qw(cc gcc clang)),
        ln => $ENV{LN} || which('ln'),
        distfile => 'FIXME',
#FIXME:finalize distfile   "$program-$version.tar.gz" 
        header => +{},
        );

# Symbols to be exported to config.h
#
my @c_exports = (qw(project version target api cflags));

# Symbols to be exported to config.mk
#
my @make_exports= (qw(project version target api distfile 
              prefix bindir sbindir libdir includedir mandir 
              cflags ldflags libs
              cc ln ar install));
#FIXME: abi_major abi_minor abi_version diff mans headers extra_dist subdirs 

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

sub compile {
    my $code = shift;

    my ($fh, $filename) = tempfile('mcXXXXXXXXXX', 
            SUFFIX => '.c',
            UNLINK => 1,
            );
    print $fh $code or die $!;
    close($fh) or die $!;

    my $cmd = "$sym{cc} $sym{cflags} $filename";
    if ($verbose > 1) {
        print "\ncompiling with '$cmd`:\n" . 
              ('-' x 72) . "\n" . 
              $code . "\n" .
              ('-' x 72) . "\n"; 
    } else {
        $cmd .= " >/dev/null 2>&1";
    }
    system $cmd;
    if ($? == -1) {
        die "failed to execute: $!\n";
    } elsif ($? & 127) {
        die "child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
    } else {
        return ($? >> 8);
    }
}

sub print_usage {
    die 'TODO -- usage';
    exit(0);
}

sub print_version {
    print "makeconf r$version\n";
    exit(0);
}

sub parse_conffile {
    my $infile = 'config.inc2';
    if (-e $infile) {
        open (my $fd, "<$infile") or die "$infile: $!";
        my @lines = <$fd> or die $!;
        close($fd) or die $!;
        eval join('',@lines);
        die $@ if $@;
    } else {
        die "$infile: file not found";
    }
}

sub parse_argv {
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
        ) or exit(1);

    # Process options that trigger an action
    #
    my %dispatch = (
            help => \&print_usage,
            version => \&print_version,
# FIXME:if [ "$id" = "generate-rpath" ] ; then
            );
    foreach (keys %dispatch) {
        next unless exists $opt{$_};
        $dispatch{$_}($opt{$_}) if exists $opt{$_};
        delete $opt{$_};
    }
    
    # Process options that modify the symbol table
    #
    foreach my $key (keys %opt) {
        $sym{$key} = $opt{$key};
    }

    # Process options that modify global settings
    #
    $verbose++ if $opt{verbose};
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

sub check_project {
    unless ($sym{project}) {
        my $x = basename(getcwd);
        $x =~ s/-[0-9].*$//;        # remove version number
        $sym{project} = $x;
    }

    # Generate default values for missing elements
    while (my ($id, $proj) = each %project) {
# TODO:
    }
}

sub check_target {
    print "checking operating system type.. ";
    $sym{target} = $^O;
    $sym{api} = 'posix';
    if ($^O eq 'MSWin32') {
        $sym{target} = 'windows';
        $sym{api} = 'windows';
    }
    print "$sym{target}\n";
}

sub check_compiler {
    print "checking for a C compiler.. $sym{cc}\n";
    die 'not found' unless $sym{cc};
}

sub check_archiver {
    print "checking for a suitable archiver.. ";
    $sym{ar} = $ENV{AR} || which(qw(ar gar)) || die 'not found';
    print "$sym{ar}\n";
}

sub check_install {
    print "checking for a BSD-compatible install.. ";
    $sym{install} = $ENV{INSTALL} || which(qw(install)) || die 'not found';
    if ($sym{target} eq 'solaris' and $sym{install} eq '/usr/bin/install') {
        $sym{install}='/usr/ucb/install';
    }
    print "$sym{install}\n";
}

sub export_to_c {
    print "Creating config.h\n";
    open (my $fd, ">config.h") or die "open of config.h: $!";
    my @cpp_define = map { 
                    die "missing symbol: $_" unless exists $sym{$_};
                    die "undefined symbol: $_" unless defined $sym{$_};
                    '#define ' . uc($_) . ' ' . $sym{$_} . "\n";
                    } @c_exports;
    print $fd "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n", @cpp_define or die;
    foreach my $key (keys %{$sym{header}}) {
        my $header = uc $key;
        $header =~ tr/[.\/\-]/_/;
        if ($sym{header}->{$key}) {
            print $fd "#define HAVE_$header 1\n";
        } else {
            print $fd "#undef  HAVE_$header\n";
        }
    }
    close($fd) or die;
}
    
# Translate linker options from GCC syntax to the local linker syntax
#
sub convert_ldflags {
    my (@token) = @_;
    my @res;
    
    foreach my $x (@token) {
        if ($sym{target} eq 'solaris') {
            if ($x =~ /^-Wl,-rpath,(.*?)/) {
                $x = "-R $1";
            } elsif ($x =~ /-Wl,-soname,(.+)/) {
                $x = "-h $1";
            } elsif ($x =~ /-Wl,-export-dynamic/) {
                undef $x;
            }
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
    my ($type,$output,$proj,$rec) = @_;

    # Generate the dependency list
    #
    my (@depends) = @{ $rec->{sources} };
    push @depends, @{ $rec->{depends} } if exists $rec->{depends};

    # Generate the compiler flags
    #
    my @cflags = ('$(CFLAGS)');
    push @cflags, @{$proj->{cflags}} if exists $proj->{cflags};
    push @cflags, @{$rec->{cflags}} if exists $rec->{cflags};
    unshift @cflags, '-shared', '-fpic' if $output eq 'library';

    # Generate the linker flags
    #
    my @ldflags = ('$(LDFLAGS)');
    push @ldflags, $proj->{ldflags} if exists $proj->{ldflags};
    push @ldflags, $rec->{ldflags} if exists $rec->{ldflags};
    (@ldflags) = convert_ldflags(@ldflags);

    # Generate the additional library list
    #
    my (@libs) = ('$(LIBS)');
    push @libs, $proj->{libs} if exists $proj->{libs};
    push @libs, @{ $rec->{libs} } if exists $rec->{libs};

    return  "\n" .
            "$output: " . join(' ', @depends) . "\n" .
            "\t\$(CC)" .
            " -o $output" .
            " " . join(' ', @cflags) .
            " " . join(' ', @ldflags) .
            " " . join(' ', @{ $rec->{sources} }) .
            " " . join(' ', @libs) .
            "\n";
}

sub export_to_make {
    print "Creating config.mk\n";
    $sym{prefix} = '$(DESTDIR)' . $sym{prefix};
    open (my $fd, ">config.mk") or die "open of config.mk: $!";
    my @def = map {
                    die "missing symbol: $_" unless exists $sym{$_};
                    uc($_) . '=' . $sym{$_} . "\n";
              } @make_exports;
    print $fd "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n", @def or die;

    # Generate the 'all' target
    #
    my (@all);
    foreach my $p (values %project) {
        $p->{binary} ||= +{};
        $p->{library} ||= +{};
        push @all, keys %{$p->{binary}};
        push @all, keys %{$p->{library}};
    } 
    print $fd "\nall: " . join(' ', @all) . "\n";

    # Generate the 'clean' target
    #
    print $fd "\nclean:\n\trm -f " . join(' ', @all) . "\n";

    # Generate all binary targets
    #
    foreach my $p (values %project) {
        while (my ($key,$rec) = each %{$p->{binary}}) {
            print $fd generate_make_target('binary', $key, $p, $rec);
        }
    } # each project

    close($fd) or die;
}

sub check_header {
    my $result = 1;
    foreach my $header (@_) {
        print "checking for $header... ";
        my $code = "#include <$header>\nint main() {}\n";
        if (compile($code) != 0) {
            print "no\n";
            $sym{header}->{$header} = 0;
            $result = 0;
        } else {
            print "yes\n";
            $sym{header}->{$header} = 1;
        }
    }
    return $result;
}

sub check_symbol {
    my ($header,$symbol) = @_;
    my $code;
    my $found = 0;

    # Check that the header is available
    #
    check_header($header) unless exists $sym{header}->{$header};
    if ($sym{header}->{$header} == 0) {
        print "checking $header for $symbol... no ($header is missing)\n";
        return 0; 
    }

    print "checking $header for $symbol... ";

    # See if the symbol is a macro
    #
    $code = "
        #include <$header>
        #if !defined($symbol)
        #error no
        #endif
        int main() {}\n";
    if (compile($code) == 0) {
        $found = 1;
    }

    # See if the symbol is an actual symbol
    #
    $code = "#include <$header>\nint main() { void *p; p = &$symbol; }\n";
    if (not $found and compile($code) == 0) {
        $found = 1;
    }

out:
    print $found ? "yes" : "no", "\n";
    $sym{macro}->{$symbol} = $found;
    return $found;
}

#######################################################################
#
#                           MAIN()
#
#######################################################################

parse_argv();
check_project();
check_target();
check_compiler();
check_archiver();
check_install();

parse_conffile();

#subst_vars "$program.pc"
#subst_vars "$program.la"
#if [ "$target" = "linux" ] ; then
#  subst_vars "rpm.spec"
#fi

export_to_c();
export_to_make();

#warn Dumper(\%sym);
#warn Dumper(\%project);