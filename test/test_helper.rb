require 'simplecov'
SimpleCov.start { command_name "test" }

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'manageiq/gems/pending'

require 'pathname'
require 'sys-uname'
def smartstate_images_root
  @smartstate_images_root ||= Pathname.new(Sys::Platform::IMPL == :macosx ? "/Volumes" : "/mnt").join("manageiq/fleecing_test/images")
end

require 'minitest/autorun'
