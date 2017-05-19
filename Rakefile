require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rake'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--options #{File.expand_path(".rspec_ci", __dir__)}" if ENV['CI']
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/ts_*.rb'] - ['test/ts_mdfs.rb', 'test/ts_metadata.rb']
end

namespace :test do
  Rake::TestTask.new(:extract)  { |t| t.test_files = ['test/ts_extract.rb'] }
  Rake::TestTask.new(:metadata) { |t| t.test_files = ['test/ts_metadata.rb'] }
  Rake::TestTask.new(:miq_disk) { |t| t.test_files = ['test/ts_mdfs.rb'] }
end

task :default do
  Rake::Task["spec"].invoke
  Rake::Task["test"].invoke
end
