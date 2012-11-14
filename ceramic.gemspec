require File.expand_path("../lib/ceramic/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "ceramic"
  s.version     = Ceramic::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Ceramic"
  s.description = "Tools for building JSON tiles from OpenStreetMap data"
  s.authors     = ["Mike Daines"]
  s.email       = "mike@mdaines.com"
  s.files       = Dir["{lib}/**/*.rb", "bin/*", "COPYING", "*.md", "lib/viewer/**/*"]
  s.require_path = "lib"
  s.add_dependency "json", "~> 1.7.3"
  s.add_dependency "pg", "~> 0.14.1"
  s.add_dependency "rack", "~> 1.4.1"
  s.add_dependency "sinatra", "~> 1.3.2"
  s.executables = ["ceramic", "ceramic-tirex-backend"]
  s.homepage    = "http://github.com/mdaines/ceramic"
end
