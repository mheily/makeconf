# A target is a section in a Makefile
class Target

  def initialize(objs, deps = [], rules = [])
      deps = [ deps ] if deps.kind_of?(String)
      rules = [ rules ] if rules.kind_of?(String)
      raise ArgumentError.new('Bad objs') unless objs.kind_of?(String)
      raise ArgumentError.new('Bad deps') unless deps.kind_of?(Array)
      raise ArgumentError.new('Bad rules') unless rules.kind_of?(Array)

      @objs = objs
      @deps = deps
      @rules = rules
      @dirs_to_create = []      # directories to create
      @files_to_copy = {}       # files to be copied
  end

  # Merge one target with another
  def merge!(src)
      raise ArgumentError.new('Mismatched object') \
          unless src.objs == @objs
      @deps.push(src.deps).uniq!
      @rules.push(src.rules).flatten!
      @dirs_to_create.push(src.dirs_to_create).flatten!.uniq!
      @files_to_copy.merge!(src.files_to_copy)
  end

  # Ensure that a directory is created before any rules are evaluated
  def mkdir(path)
    @dirs_to_create.push(path) unless @dirs_to_create.include?(path)
  end

  # Copy a file to a directory. This is more efficient than calling cp(1)
  # for each file.
  def cp(src,dst)
    @files_to_copy[dst] ||= []
    @files_to_copy[dst].push(src)
  end

  def add_dependency(depends)
    @deps.push(depends).uniq!
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def prepend_rule(target,rule)
    @rules.unshift(rule)
  end

  # Return the string representation of the target
  def to_s
    res = "\n" + @objs + ':'
    res += ' ' + @deps.join(' ') if @deps
    res += "\n"
    unless @dirs_to_create.empty?
       res += "\t" + Platform.mkdir(@dirs_to_create) + "\n"
    end
    @files_to_copy.each do |k,v|
       res += "\t" + Platform.cp(v, k) + "\n"
    end
    @rules.each { |r| res += "\t" + r + "\n" }
    res
  end

  protected

  attr_reader :objs, :deps, :rules, :dirs_to_create, :files_to_copy
end
