#!/usr/bin/env ruby
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

class Makeconf
  require 'optparse'
  require 'pp'

  require 'makeconf/buildable'
  require 'makeconf/binary'
  require 'makeconf/compiler'
  require 'makeconf/gui'
  require 'makeconf/installer'
  require 'makeconf/library'
  require 'makeconf/linker'
  require 'makeconf/makefile'
  require 'makeconf/packager'
  require 'makeconf/platform'
  require 'makeconf/project'
  require 'makeconf/target'

  @@installer = Installer.new
  @@makefile = Makefile.new

  def Makeconf.parse_options(args = ARGV)
     x = OptionParser.new do |opts|
       opts.banner = 'Usage: configure [options]'

       @@installer.parse_options(opts)

       opts.separator ''
       opts.separator 'Common options:'

       opts.on_tail('-h', '--help', 'Show this message') do
         puts opts
          exit
       end

       opts.on_tail('-V', '--version', 'Display version information and exit') do
         puts OptionParser::Version.join('.')
         exit
       end
    end

    x.parse!(args)
  end

  # Examine the operating environment and set configuration options
  def Makeconf.configure(project)
    project = Project.new(project) if project.kind_of?(Hash)

    # FIXME: once the GUI is finished, it should just be
    # if Platform.is_graphical?
    if ENV['MAKECONF_GUI'] == 'yes' and Platform.is_graphical?
      ui = Makeconf::GUI.new(project)
      ui.main_loop
    else
      Makeconf.configure_project(project)
    end
  end

  private


  # Examine the operating environment and set configuration options
  def Makeconf.configure_project(project)
     parse_options

     makefile = Makefile.new
     toplevel_init(makefile)

     @@installer.configure(project)
     project.makefile = @@makefile
     project.installer = @@installer
     project.configure
     project.finalize 
     project.write_config_h
     makefile.merge! project.to_make

     puts 'creating Makefile'
     makefile.write('Makefile')
  end

  # Add rules and targets used in the top-level Makefile
  def Makeconf.toplevel_init(makefile)
    makefile.add_target('dist', [], [])
    makefile.add_dependency('distclean', 'clean')
    makefile.add_rule('distclean', Platform.rm('Makefile'))

    # Prepare the destination tree for 'make install'
    makefile.add_rule('install', Platform.is_windows? ?
            'dir $(DESTDIR)' + Platform.dev_null :
            '/usr/bin/test -e $(DESTDIR)')

    # Distribute Makeconf with 'make distdir'
    makefile.distribute(['setup.rb', 'configure', 'makeconf/*.rb'])
  end

end
