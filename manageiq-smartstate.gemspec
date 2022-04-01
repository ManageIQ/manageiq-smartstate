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
    f.match(%r{^(spec|features)/|test/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "awesome_spawn",      "~> 1.5"
  spec.add_dependency "azure-armrest",      "~> 0.9"
  spec.add_dependency "binary_struct",      "~> 2.1"
  spec.add_dependency "iniparse"
  spec.add_dependency "linux_block_device", "~>0.2.1"
  spec.add_dependency "manageiq-password",  "< 2"
  spec.add_dependency "memory_buffer",      ">=0.1.0"
  spec.add_dependency "rufus-lru",          "~>1.0.3"
  spec.add_dependency "sys-uname",          "~>1.2.1"
  spec.add_dependency "uuidtools",          "~>2.1"
  spec.add_dependency "vmware_web_service", "~>3.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "camcorder"
  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec",     "~> 3.0"
  spec.add_development_dependency "simplecov", ">= 0.21.2"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "vcr",       "~>3.0.2"
  spec.add_development_dependency "webmock",   "~>2.3.1"
end
