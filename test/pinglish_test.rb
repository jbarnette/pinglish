require "minitest/autorun"
require "rack"
require "rack/test"
require "pinglish"

class PinglishTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new do |builder|
      builder.use Pinglish
      builder.run lambda { |env| [404, {}, []] }
    end
  end

  def test_sanity
    assert true
  end

  def test_default_path_and_status
    get '/_ping'
    assert_equal 200, last_response.status
  end
end
