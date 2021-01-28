require_relative './test_helper'

# Setup console logging
require 'logger'
$log = Logger.new(File.expand_path("../log/ts_extract.log", __dir__))
$log.level = Logger::DEBUG

require_relative 'extract/tc_versioninfo.rb'
require_relative 'extract/tc_md5deep.rb'
require_relative 'extract/tc_registry.rb'
