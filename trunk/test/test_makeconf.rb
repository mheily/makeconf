require 'test/unit'
require 'makeconf'

class MakeconfTest < Test::Unit::TestCase
  def test_constructor
    assert_not_nil(Makeconf.new)
  end
end
