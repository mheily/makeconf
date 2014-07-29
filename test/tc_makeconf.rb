#!/usr/bin/env ruby

require 'test/unit'

class MakeconfTest < Test::Unit::TestCase
  require 'makeconf'
  def test_constructor
    assert_not_nil(Makeconf.new)
  end
end
