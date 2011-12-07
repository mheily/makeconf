#
# Abstraction for platform-specific system commands and variables
# This class only contains static methods.
#
class Platform

  attr_reader :host_os, :target_os

  require 'rbconfig'

  # TODO: allow target_os to be overridden for cross-compiling

  @@host_os = Config::CONFIG['host_os']
  @@target_os = @@host_os

  # Returns true or false depending on if the target is MS Windows
  def Platform.is_windows?
    @@target_os =~ /mswin|mingw/
  end

  # Returns true or false depending on if the target is Solaris
  def Platform.is_solaris?
    @@target_os =~ /^solaris/
  end

  # Returns true or false depending on if the target is Linux
  def Platform.is_linux?
    @@target_os =~ /^linux/
  end

  # Returns true or false depending on if the target is x86-compatible
  def Platform.is_x86?
    Config::CONFIG['host_cpu'] =~ /^(x86_64|i386)$/ ? true : false
  end

  # Returns the name of the operating system vendor
  def Platform.vendor
    return 'Fedora' if File.exists?('/etc/fedora-release')
    return 'Red Hat' if File.exists?('/etc/redhat-release')
    return 'Debian' if File.exists?('/etc/debian_version')
    return 'Unknown' 
  end
  
  # Returns the native word size
  def Platform.word_size
    if @@host_os =~ /^solaris/
      `/usr/bin/isainfo -b`.to_i
    elsif @@host_os =~ /^linux/
      if `/usr/bin/file /bin/bash` =~ /32-bit/
        return 32
      else
        return 64
      end
    else
      throw 'Unknown word size'
    end
  end

  def Platform.archiver(archive,members)
    if is_windows? && ! ENV['MSYSTEM']
      'lib.exe ' + members.join(' ') + ' /OUT:' + archive
    else
      # TODO: add '/usr/bin/strip --strip-unneeded' + archive
      'ar rs ' + archive + ' ' + members.join(' ')
   end
  end

  # Create a directory and all of it's components
  def Platform.mkdir(path)
    if path.kind_of?(Array)
        path = path.flatten.join(' ')
    end
    throw 'invalid path' if path.nil? or path == ''
    if is_windows?
       throw 'FIXME'
    else
       "umask 22 ; mkdir -p '#{path}'"
    end
  end

  # Remove a regular file
  def Platform.rm(path)
    if path.kind_of?(Array)
        path = path.join(' ')
    end
    if is_windows? && ! ENV['MSYSTEM']
      return 'del /F ' + path
    else
      return 'rm -f ' + path
    end
  end

  # Remove a directory along with all of it's contents
  def Platform.rmdir(path)
    is_windows? ? "rmdir /S /Q #{path}" : "rm -rf #{path}"
  end

  def Platform.cp(src,dst)
    if src.kind_of?(Array)
      src = src.join(' ')
    end

    if is_windows? && ! ENV['MSYSTEM']
      return "copy #{src} #{dst}"
    else
      return "cp #{src} #{dst}"
    end
  end

  # Send all output to /dev/null or it's equivalent
  def Platform.dev_null
    if is_windows? && ! ENV['MSYSTEM'] 
      ' >NUL 2>NUL' 
    else
      ' >/dev/null 2>&1'
    end
  end

  # Send standard error to /dev/null or it's equivalent
  def Platform.dev_null_stderr
    if is_windows? && ! ENV['MSYSTEM'] 
      ' 2>NUL' 
    else
      ' 2>/dev/null'
    end
  end

  # The extension used for executable files 
  def Platform.executable_extension
    is_windows? ? '.exe' : ''
  end

  # The extension used for intermediate object files 
  def Platform.object_extension
    is_windows? ? '.obj' : '.o'
  end

  # The extension used for static libraries
  def Platform.static_library_extension
    is_windows? ? '.lib' : '.a'
  end

  # The extension used for shared libraries
  def Platform.shared_library_extension
    is_windows? ? '.dll' : '.so'
  end

  # Emulate the which(1) command
  def Platform.which(command)
    return nil if is_windows?      # FIXME: STUB
    ENV['PATH'].split(':').each do |prefix|
      path = prefix + '/' + command
      return command if File.executable?(path)
    end
    nil
  end

end
