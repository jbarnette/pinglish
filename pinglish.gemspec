# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "pinglish"
  gem.version       = "0.2.1"
  gem.authors       = ["John Barnette", "Will Farrington"]
  gem.email         = ["jbarnette@github.com", "wfarr@github.com"]
  gem.description   = "A simple Rack middleware for checking app health."
  gem.summary       = "/_ping your way to freedom."
  gem.homepage      = "https://github.com/jbarnette/pinglish"

  gem.files         = `git ls-files`.split $/
  gem.test_files    = gem.files.grep /^test/
  gem.require_paths = ["lib"]

  gem.add_dependency "rack"
  gem.add_development_dependency "minitest", "~> 4.5"
  gem.add_development_dependency "rack-test", "~> 0.6"
end
