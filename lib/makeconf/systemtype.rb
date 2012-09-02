# Detect the build system type and allow for cross-compilation
#
class SystemType

  # FIXME: detect 'build' properly
  @@build = RbConfig::CONFIG['host_os']
  @@host = nil
  @@target = nil

  if ARGV.grep(/^--build=(.*)$/)
    @@build = $1
  end

  if ARGV.grep(/^--host=(.*)$/)
    @@host = $1
  end

  if ARGV.grep(/^--target=(.*)$/)
    @@target = $1
  end

  def SystemType.build
    @@build
  end

  def SystemType.host
    @@host
  end

  def SystemType.target
    @@target
  end

end
