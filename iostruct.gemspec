# frozen_string_literal: true

require 'English'
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iostruct/version'

Gem::Specification.new do |s|
  s.name = "iostruct"
  s.version = IOStruct::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors  = ["Andrey \"Zed\" Zaikin"]
  s.email    = "zed.0xff@gmail.com"
  s.files    = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  s.homepage = "http://github.com/zed-0xff/iostruct"
  s.licenses = ["MIT"]
  s.summary  = "A Struct that can read/write itself from/to IO-like objects"

  s.require_paths = ["lib"]

  s.metadata['rubygems_mfa_required'] = 'true'
end
