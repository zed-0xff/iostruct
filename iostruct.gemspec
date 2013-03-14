# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iostruct/version'

Gem::Specification.new do |s|
  s.name = "iostruct"
  s.version = IOStruct::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors  = ["Andrey \"Zed\" Zaikin"]
  s.date     = "2013-01-08"
  s.email    = "zed.0xff@gmail.com"
  s.files    = `git ls-files`.split($/)
  s.homepage = "http://github.com/zed-0xff/iostruct"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.summary  = "A Struct that can read/write itself from/to IO-like objects"

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
end

