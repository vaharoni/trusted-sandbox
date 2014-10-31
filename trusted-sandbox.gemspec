# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trusted_sandbox/version'

Gem::Specification.new do |spec|
  spec.name          = 'trusted-sandbox'
  spec.version       = TrustedSandbox::VERSION
  spec.authors       = ['Amit Aharoni']
  spec.email         = ['amit.sites@gmail.com']
  spec.description   = %q{Trusted Sandbox makes it simple to execute classes that eval untrusted code in a resource-controlled docker container}
  spec.summary       = %q{Run untrusted code in a contained sandbox using Docker}
  spec.homepage      = 'https://github.com/vaharoni/trusted-sandbox'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rr'

  spec.add_runtime_dependency 'docker-api', '~> 1.13'
  spec.add_runtime_dependency 'thor', '~> 0.19'
end