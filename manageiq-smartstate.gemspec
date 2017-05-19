# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/smartstate/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-smartstate"
  spec.version       = ManageIQ::Smartstate::VERSION
  spec.authors       = ["ManageIQ Developers"]

  spec.summary       = "ManageIQ SmartState Analysis"
  spec.description   = "ManageIQ SmartState Analysis"
  spec.homepage      = "https://github.com/ManageIQ/manageiq-smartstate"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "manageiq-gems-pending"
  spec.add_dependency "vmware_web_service", "~>0.1.1"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "camcorder"
  spec.add_development_dependency "vcr", "~>3.0.2"
  spec.add_development_dependency "webmock", "~>1.12"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"

end
