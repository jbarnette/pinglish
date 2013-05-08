# Pinglish

A simple Rack middleware for checking application health. Pinglish
exposes a `/_ping` resource via HTTP `GET`, returning JSON that
conforms to the spec below.

## The Spec

0. The application __must__ respond to `GET /_ping` as an HTTP request.

0. The request handler __should__ check the health of all services the
  application depends on, answering questions like, "Can I query
  agains my MySQL database," "Can I create/read keys in Redis," or "How
  many docs are in my ElasticSearch index?"

0. The response __must__ return within 29 seconds. This is one second
   less than the default timeout for many monitoring services.

0. The response __must__ return an `HTTP 200 OK` status code if all
   health checks pass.

0. The response __must__ return an `HTTP 503 SERVICE UNAVAILABLE`
   status code if any health checks fail.

0. The response __must__ be of Content-Type `application/json;
   charset=UTF-8`.

0. The response __must__ be valid JSON no matter what, even if JSON
   serialization or other fundamental code fails.

0. The response __must__ contain a `"status"` key set either to `"ok"`
   or `"failures"`.

0. The response __must__ contain a `"now"` key set to the current
   server's time in seconds since epoch as a string.

0. If the `"status"` key is set to `"failures"`, the response __may__
   contain a `"failures"` key set to an Array of string names
   representing failed checks.

0. If the `"status"` key is set to `"failures"`, the response __may__
   contain a `"timeouts"` key set to an Array of string names
   representing checks that exceeded an implementation-specific
   individual timeout.

0. The response body __may__ contain any other top-level keys to
   supply additional data about services the application consumes, but
   all values must be strings, arrays of strings, or hashes where both
   keys and values are strings.

### An Example Response

```javascript
{

  // These two keys will always exist.

  "now": "1359055102",
  "status": "failures",

  // This key may only exist when a named check has failed.

  "failures": ["db"],

  // This key may only exist when a named check exceeds its timeout.

  "timeouts": ["really-long-check"],

  // Keys like this may exist to provide extra information about
  // healthy services, like the number of objects in an S3 bucket.

  "s3": "127"
}
```

## The Middleware

```ruby
require "pinglish"

use Pinglish do |ping|

  # A single unnamed check is the simplest possible way to use
  # Pinglish, and you'll probably never want combine it with other
  # named checks. An unnamed check contributes to overall success or
  # failure, but never adds additional data to the response.

  ping.check do
    App.healthy?
  end

  # A named check like this can provide useful summary information
  # when it succeeds. In this case, a top-level "db" key will appear
  # in the response containing the number of items in the database. If
  # a check returns nil, no key will be added to the response.

  ping.check :db do
    App.db.items.size
  end

  # By default, checks time out after one second. You can override
  # this with the :timeout option, but be aware that no combination of
  # checks is ever allowed to exceed the overall 29 second limit.

  ping.check :long, :timeout => 5 do
    App.dawdle
  end

  # Signal check failure by raising an exception. Any exception will do.
  ping.check :fails do
    raise "Everything's ruined."
  end

  # Additionally, any check that returns false is counted as a failure.
  ping.check :false_fails do
    false
  end
end
```
