require "json"
require "pinglish/check"
require "rack/request"
require "timeout"

# This Rack middleware provides a "/_ping" endpoint for configurable
# system health checks. It's intended to be consumed by machines.

class Pinglish

  # The HTTP headers sent for every response.

  HEADERS = {
    "Content-Type" => "application/json; charset=UTF-8"
  }

  # Raised when a check exceeds its timeout.

  class TooLong < RuntimeError; end

  # Create a new instance of the middleware wrapping `app`, with an
  # optional `:path` (default: `"/_ping"`), `:max` timeout in seconds
  # (default: `29`), and behavior `block`.

  def initialize(app, options = nil, &block)
    options ||= {}

    @app    = app
    @checks = {}
    @max    = options[:max] || 29 # seconds
    @path   = options[:path] || "/_ping"

    yield self if block_given?
  end

  # Exercise the middleware, immediately delegating to the wrapped app
  # unless the request path matches `path`.

  def call(env)
    request = Rack::Request.new env

    return @app.call env unless request.path_info == @path

    begin
      timeout @max do
        results  = {}

        @checks.values.each do |check|
          begin
            timeout check.timeout do
              results[check.name] = check.call
            end
          rescue StandardError => e
            results[check.name] = e
          end
        end

        failed      = results.values.any? { |v| failure? v }
        http_status = failed ? 503 : 200
        text_status = failed ? "failures" : "ok"

        data = {
          :now    => Time.now.to_i.to_s,
          :status => text_status
        }

        results.each do |name, value|

          # The unnnamed/default check doesn't contribute data.
          next if name.nil?

          if failure? value

            # If a check fails its name is added to a `failures` array.
            # If the check failed because it timed out, its name is
            # added to a `timeouts` array instead.

            key = timeout?(value) ? :timeouts : :failures
            (data[key] ||= []) << name

          elsif value

            # If the check passed and returned a value, the stringified
            # version of the value is returned under the `name` key.

            data[name] = value.to_s
          end
        end

        [http_status, HEADERS, [JSON.generate(data)]]
      end

    rescue Exception => ex

      # Something catastrophic happened. We can't even run the checks
      # and render a JSON response. Fall back on a pre-rendered string
      # and interpolate the current epoch time.

      now = Time.now.to_i.to_s
      [500, HEADERS, ['{"status":"failures","now":"' + now + '"}']]
    end
  end

  # Add a new check with optional `name`. A `:timeout` option can be
  # specified in seconds for checks that might take longer than the
  # one second default. A previously added check with the same name
  # will be replaced.

  def check(name = nil, options = nil, &block)
    @checks[name] = Check.new(name, options, &block)
  end

  # Does `value` represent a check failure? This default
  # implementation returns `true` for any value that is an Exception or false.
  # Subclasses can override this method for different behavior.

  def failure?(value)
    value.is_a?(Exception) || value == false
  end

  # Raise Pinglish::TooLong after `seconds` has elapsed. This default
  # implementation uses Ruby's built-in Timeout class. Subclasses can
  # override this method for different behavior, but any new
  # implementation must raise Pinglish::TooLong when the timeout is
  # exceeded or override `timeout?` appropriately.

  def timeout(seconds, &block)
    Timeout.timeout seconds, Pinglish::TooLong, &block
  end

  # Does `value` represent a check timeout? Returns `true` for any
  # value that is an instance of Pinglish::TooLong.

  def timeout?(value)
    value.is_a? Pinglish::TooLong
  end
end
