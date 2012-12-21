# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano-zen/version'

Gem::Specification.new do |gem|
  gem.name          = "capistrano-zen"
  gem.version       = Capistrano::Zen::VERSION
  gem.authors       = ["Steven Yang"]
  gem.email         = ["yangchenyun@gmail.com"]
  gem.description   = %q{Capistrano Recipes used at zenhacks.org.}
  gem.summary       = %q{Nginx, Unicorn, PostgreSQL, NodeJS Recipes install on a machine running Ubuntu. }
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.extra_rdoc_files = [
    "LICENSE"
  ]

  gem.add_dependency "capistrano", ">= 2.5.3"
  gem.add_development_dependency "rake"
end
