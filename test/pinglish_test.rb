require "helper"
require "rack/test"

class PinglishTest < MiniTest::Unit::TestCase
  FakeApp = lambda { |env| [200, {}, ["fake"]] }

  def build_app(*args, &block)
    Rack::Builder.new do |builder|
      builder.use Pinglish, *args, &block
      builder.run FakeApp
    end
  end

  def test_with_non_matching_request_path
    app = build_app

    session = Rack::Test::Session.new(app)
    session.get "/something"
    assert_equal 200, session.last_response.status
    assert_equal "fake", session.last_response.body
  end

  def test_with_non_matching_request_path_and_exception
    app = Rack::Builder.new do |builder|
      builder.use Pinglish
      builder.run lambda { |env| raise "boom" }
    end

    session = Rack::Test::Session.new(app)

    assert_raises RuntimeError do
      session.get "/something"
    end
  end

  def test_with_defaults
    app = build_app

    session = Rack::Test::Session.new(app)
    session.get "/_ping"
    assert_equal 200, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "ok", json["status"]
  end

  def test_with_good_check
    app = build_app do |ping|
      ping.check(:db) { :up_and_at_em }
      ping.check(:queue) { :pushin_and_poppin }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "ok", json["status"]
    assert_equal "up_and_at_em", json["db"]
    assert_equal "pushin_and_poppin", json["queue"]
  end

  def test_with_unnamed_check
    app = build_app do |ping|
      ping.check { :yohoho }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "ok", json["status"]
  end

  def test_with_check_that_raises
    app = build_app do |ping|
      ping.check(:db) { :ok }
      ping.check(:raise) { raise "nooooope" }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal 503, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "failures", json["status"]
  end

  def test_with_check_that_returns_false
    app = build_app do |ping|
      ping.check(:db) { :ok }
      ping.check(:fail) { false }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal 503, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "failures", json["status"]
    assert_equal ["fail"], json["failures"]
  end

  def test_with_check_that_times_out
    app = build_app do |ping|
      ping.check(:db) { :ok }
      ping.check(:long, :timeout => 0.001) { sleep 0.003 }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal 503, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "failures", json["status"]
    assert_equal ["long"], json["timeouts"]
  end

  def test_with_checks_taking_more_than_max
    app = build_app(:max => 0.001) do |ping|
      ping.check(:long) { sleep 0.003 }
    end

    session = Rack::Test::Session.new(app)
    session.get "/_ping"

    assert_equal 503, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "failures", json["status"]
  end

  def test_with_script_name
    app = build_app

    session = Rack::Test::Session.new(app)
    session.get "/_ping", {}, "SCRIPT_NAME" => "/myapp"
    assert_equal 200, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "ok", json["status"]
  end

  def test_with_custom_path
    app = build_app(:path => "/_piiiiing")

    session = Rack::Test::Session.new(app)
    session.get "/_piiiiing"
    assert_equal 200, session.last_response.status
    assert_equal "application/json; charset=UTF-8",
      session.last_response.content_type

    json = JSON.load(session.last_response.body)
    assert json.key?("now")
    assert_equal "ok", json["status"]
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
    assert pinglish.failure?(false)

    refute pinglish.failure?(true)
    refute pinglish.failure?(:ok)
  end

  def test_timeout
    pinglish = Pinglish.new(FakeApp)

    assert_raises Pinglish::TooLong do
      pinglish.timeout(0.001) { sleep 0.003 }
    end
  end

  def test_timeout_boolean
    pinglish = Pinglish.new(FakeApp)

    assert pinglish.timeout?(Pinglish::TooLong.new)
    refute pinglish.timeout?(Exception.new)
  end
end
