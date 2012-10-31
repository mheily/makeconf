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
  require 'logger'

  require 'makeconf/buildable'
  require 'makeconf/binary'
  require 'makeconf/compiler'
  require 'makeconf/externalproject'
  require 'makeconf/gui'
  require 'makeconf/header'
  require 'makeconf/installer'
  require 'makeconf/library'
  require 'makeconf/linker'
  require 'makeconf/makefile'
  require 'makeconf/packager'
  require 'makeconf/platform'
  require 'makeconf/project'
  require 'makeconf/systemtype'
  require 'makeconf/target'
  require 'makeconf/test'

  @@project = nil
  @@installer = Installer.new
  @@makefile = Makefile.new
  @@original_argv = ARGV.clone   # OptionParser seems to clobber this..
  
  @@logger = Logger.new(STDOUT)
  #TODO:@@logger = Logger.new('config.log')
  @@logger.datetime_format = ''
  if ENV['MAKECONF_DEBUG'] == 'yes'
    @@logger.level = Logger::DEBUG
  else
    @@logger.level = Logger::WARN
  end

  def Makeconf.original_argv
    @@original_argv.clone
  end

  def Makeconf.logger
    @@logger
  end

  def Makeconf.parse_options(args = ARGV)
    reject_unknown_options = true

    x = OptionParser.new do |opts|
       opts.banner = 'Usage: configure [options]'

       @@installer.parse_options(opts)
       @@project.parse_options(opts)

       # Cross-compilation options
       opts.separator ''
       opts.separator 'System types:'

       opts.on('--build BUILD', 'set the system type for building') do |arg|
         @@build = arg
       end
       opts.on('--host HOST', 'cross-compile programs to run on a different system type') do |arg|
         @@host = arg
       end
       opts.on('--target TARGET', 'build a compiler for cross-compiling') do |arg|
         @@target = arg
       end

       opts.separator ''
       opts.separator 'Common options:'

       opts.on_tail('--disable-option-checking') {}     # NOOP

       opts.on_tail('-h', '--help', 'Show this message') do
         puts opts
          exit
       end

       opts.on_tail('-V', '--version', 'Display version information and exit') do
         puts "Makeconf $Id$"
         exit
       end
    end

    # Special case: This must be processed prior to all other options
    if args.include? '--disable-option-checking' 
      reject_unknown_options = false
    end

    # Parse all options, and gracefully resume when an invalid option 
    # is provided.
    #
    loop do
      begin
        x.parse!(args)
        rescue OptionParser::InvalidOption => e
           if reject_unknown_options 
             warn '*** ERROR *** ' + e.to_s
             exit 1
           else
             warn 'WARNING: ' + e.to_s
             next
           end
      end
      break
    end
  end

  # Examine the operating environment and set configuration options
  def Makeconf.configure(project)

    @@logger.info 'Configuring the project'
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
    @@project = project
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
    makefile.distribute([
            'configure', 
            'makeconf/*.rb',
            'makeconf/makeconf/*.rb',
     ])
  end

end
