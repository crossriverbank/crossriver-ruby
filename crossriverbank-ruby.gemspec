# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crossriverbank/version'

Gem::Specification.new do |spec|
  spec.name          = 'crossriverbank'
  spec.required_ruby_version = '>= 1.9'
  spec.version       = CrossRiverBank::VERSION
  spec.authors       = ['Cross River Bank']
  spec.email         = ['support@pcrossriverbank.com']

  spec.summary       = %q{CrossRiverBank Ruby Client}
  spec.description   = %q{CrossRiverBank Ruby Client}
  spec.homepage      = 'https://crossriverbank.com/'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('finix', CrossRiverBank::VERSION)
end
