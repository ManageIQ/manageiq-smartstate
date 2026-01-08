source 'https://rubygems.org'

# Specify your gem's dependencies in manageiq-smartstate.gemspec
gemspec

gem "manageiq-gems-pending", :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"

# Modified gems for vmware_web_service.  Setting sources here since they are git references
gem "handsoap", "=0.2.5.5", :require => false, :source => "https://rubygems.manageiq.org"

minimum_version =
  case ENV['TEST_RAILS_VERSION']
  when "8.0"
    "~>8.0.4"
  else
    "~>7.2.3"
  end

gem "activesupport", minimum_version
