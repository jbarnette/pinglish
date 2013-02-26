require "helper"

class PinglishCheckTest < MiniTest::Unit::TestCase
  def test_initialize
    check = Pinglish::Check.new(:db)
    assert_equal :db, check.name
  end

  def test_initialize_default_timeout
    check = Pinglish::Check.new(:db)
    assert_equal 1, check.timeout
  end

  def test_initialize_override_timeout
    check = Pinglish::Check.new(:db, :timeout => 2)
    assert_equal 2, check.timeout
  end

  def test_call
    check = Pinglish::Check.new(:db) { :result_of_block }
    assert_equal :result_of_block, check.call
  end
end
