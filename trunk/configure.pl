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
        ldadd => $ENV{LDADD} || '',
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

# Functions to validate and normalize elements of the symbol table
#
my %validate = (
        cflags => sub { $_ }, # TODO translate to non-GCC flags
        ldflags => sub { $_ }, # TODO translate to non-GNU ldflags
);

# Symbols to be exported to config.h
#
my @c_exports = (qw(project version target api cflags));

# Symbols to be exported to config.mk
#
my @make_exports= (qw(project version target api distfile 
              prefix bindir sbindir libdir includedir mandir 
              cflags ldflags ldadd
              cc ln ar install));
#FIXME: abi_major abi_minor abi_version diff mans headers extra_dist subdirs 

=pod
required_headers=
optional_headers=

# Print the linker relocation path options using the
# appropriate syntax
#
print_rpath() {
    res=""
    for rpath in $*
    do
        rpath=`echo $rpath | sed 's/--generate-rpath=//'`
        if [ "$rpath" = "" ] ; then continue ; fi
        if [ `uname` = "SunOS" ] ; then
            res="$res -L $rpath -R $rpath"
        else
            res="$res -L $rpath -Wl,-rpath,$rpath"
        fi
    done
    echo $res
}

check_symbol() {
    header=$1
    symbol=$2

    uc_symbol=`echo "HAVE_$symbol" | $tr '[:lower:]' '[:upper:]' | sed 's,[./],_,g'`
    lc_symbol=`echo "have_$symbol" | $tr '[:upper:]' '[:lower:]' | sed 's,[./],_,g'`

    if [ -f "$header" ] ; then
        path="$header"
    elif [ -f "/usr/include/$header" ] ; then
        path="/usr/include/$header"
    else
        echo "*** ERROR: Cannot find <$header>"
        exit 1
    fi
     
    printf "checking $header for $symbol.. "    
    if [ "`grep $symbol $path`" != "" ] ; then
     eval "$lc_symbol=yes"
     echo "#define $uc_symbol 1" >> config.h
     echo "yes"
     return 0
    else
     eval "$lc_symbol=no"
     echo "no"
     echo "#undef $uc_symbol" >> config.h
     return 1
    fi
}


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
}

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
    
sub export_to_make {
    print "Creating config.mk\n";
    $sym{prefix} = '$(DESTDIR)' . $sym{prefix};
    open (my $fd, ">config.mk") or die "open of config.mk: $!";
    my @def = map {
                    die "missing symbol: $_" unless exists $sym{$_};
                    uc($_) . '=' . $sym{$_} . "\n";
              } @make_exports;
    print $fd "# AUTOMATICALLY GENERATED -- DO NOT EDIT\n", @def or die;
    close($fd) or die;
}

sub check_header {
    my $result = 1;
    foreach my $header (@_) {
        print "checking for $header... ";
        my ($fh, $filename) = tempfile('mcXXXXXXXXXX', 
                SUFFIX => '.c',
                UNLINK => 1,
                );
        print $fh "#include <$header>\nint main() {}\n" or die $!;
        close($fh) or die $!;
        system "$sym{cc} $sym{cflags} $filename 2>/dev/null"; #FIXME: log it
        if ($? == -1) {
            die "failed to execute: $!\n";
        }
        elsif ($? & 127) {
            die "child died with signal %d, %s coredump\n",
                   ($? & 127),  ($? & 128) ? 'with' : 'without';
        }
        else {
            if ($? >> 8) {
                print "no\n";
                $sym{header}->{$header} = 0;
                $result = 0;
            } else {
                print "yes\n";
                $sym{header}->{$header} = 1;
            }
        }
    }
    return $result;
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

=pod
cleanfiles=""
    echo "$x " 
for x in $targets
do
    dest=`echo $x | sed 's/:.*//'`
    sources=`echo $x | sed 's/^.*://' | tr ',' ' '`
    cleanfiles="$cleanfiles $dest"

    if [ "$target" = "solaris" ] ; then
         extra_ldflags="-m64 -R /usr/sfw/lib/amd64"
    fi

    if [ "`echo "$dest" | egrep '\\.so\$'`" = "$dest" ] ; then
      #FIXME:
      #abi_major=???
      #abi_minor=???
      #cflags="-o $program.so.$abi_major.$abi_minor $ldflags"

      if [ "$target" != "solaris" ] ; then
         extra_ldflags="$extra_ldflags -Wl,-export-dynamic -Wl,-soname,$dest"
      fi

      printf "\n$dest: $sources \$(${dest}_DEPENDS)\n\t\$(CC) -shared \$(CFLAGS) \$(${dest}_CFLAGS) $extra_ldflags \$(LDFLAGS) \$(${dest}_LDFLAGS) -o $dest $sources\n" >> config.mk
    else
       rpath_flags='`./configure --generate-rpath="$('$dest'_RPATH) $(RPATH)"`'

      printf "\n$dest: $sources \$(${dest}_DEPENDS)\n\t\$(CC) \$(CFLAGS) \$(${dest}_CFLAGS) \$(LDFLAGS) $extra_ldflags $rpath_flags \$(${dest}_LDFLAGS) -o $dest $sources \$(LDADD) \$(${dest}_LDADD)\n" >> config.mk
    fi
done

printf "\nall: $cleanfiles\n" >> config.mk
printf "\nclean:\n\trm -f $cleanfiles\n" >> config.mk
=cut
