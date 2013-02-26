require "helper"
require "rack/test"

class PinglishTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  FakeApp = lambda { |env| [404, {}, []] }

  def app
    Rack::Builder.new do |builder|
      builder.use Pinglish do |ping|
        ping.check(:db) { :up_and_at_em }
      end
      builder.run FakeApp
    end
  end

  def test_default_path_and_status
    get '/_ping'
    assert_equal 200, last_response.status
  end

  def test_json_response
    get '/_ping'
    json = JSON.load(last_response.body)

    assert_in_delta Time.now.to_i, json['now'].to_i, 2
    assert_equal 'ok', json['status']
    assert_equal 'up_and_at_em', json['db']
  end

  def test_customizing_path
    app = Rack::Builder.new do |builder|
      builder.use Pinglish, "/_piiiiing"
      builder.run FakeApp
    end
    session = Rack::Test::Session.new(app)
    session.get '/_piiiiing'
    assert_equal 200, session.last_response.status
  end

  def test_check_without_name
    pinglish = Pinglish.new(FakeApp)
    check = pinglish.check { :ok }
    assert_instance_of Pinglish::Check, check
  end

  def test_check_with_name
    pinglish = Pinglish.new(FakeApp)
    check = pinglish.check(:db) { :ok }
    assert_instance_of Pinglish::Check, check
    assert_equal :db, check.name
  end

  def test_failure_boolean
    pinglish = Pinglish.new(FakeApp)
    assert pinglish.failure?(Exception.new)
    assert !pinglish.failure?(:ok)
  end

  def test_timeout
    pinglish = Pinglish.new(FakeApp)
    begin
      pinglish.timeout(0.001) { sleep 0.003 }
      assert false, "Timeout did not happen, but should have."
    rescue Pinglish::TooLong => e
      # all good
    end
  end

  def test_timeout_boolean
    pinglish = Pinglish.new(FakeApp)
    assert_equal true, pinglish.timeout?(Pinglish::TooLong.new)
    assert_equal false, pinglish.timeout?(Exception.new)
  end
end
