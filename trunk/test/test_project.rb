require 'test/unit'
require 'makeconf'

class ProjectTest < Test::Unit::TestCase
  def test_constructor
    assert_not_nil(Project.new)
  end

  def test_attributes
    Project.new do |p|
      p.id = 'foo'
      p.version = '1.0'
      p.summary = 'A good program'
      p.description = <<EOF
        A really good program.
        Trust me.
EOF
      p.author = 'John Smith'
      p.license = 'BSD'
      p.config_h = 'include/config.h'
    end
  end
end
