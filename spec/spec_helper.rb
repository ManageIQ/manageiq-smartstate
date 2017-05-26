if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

require "bundler/setup"
require "manageiq-smartstate"

# Initialize the global logger that might be expected
require 'logger'
$log ||= Logger.new("/dev/null")

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(__dir__, 'support/**/*.rb'))].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

VCR.configure do |c|
  c.cassette_library_dir = TestEnvHelper.recordings_dir
  c.hook_into :webmock

  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = {
    :record                         => :once,
    :allow_unused_http_interactions => true
  }

  TestEnvHelper.vcr_filter(c)

  # c.debug_logger = File.open(Rails.root.join("log", "vcr_debug.log"), "w")
end