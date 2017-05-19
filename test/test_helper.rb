require 'simplecov'
SimpleCov.start { command_name "test" }

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'manageiq-gems-pending'

require 'minitest/autorun'
