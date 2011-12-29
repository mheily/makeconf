require 'test/unit'
require 'makeconf'

class ProjectTest < Test::Unit::TestCase
  def test_constructor
    assert_not_nil(Project.new)
  end
end
