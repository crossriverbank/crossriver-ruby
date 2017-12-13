gem 'minitest'
require 'rake'
require 'bundler/gem_tasks'
require 'rake/testtask'
require_relative 'test/helper_test'

desc 'Run test suite'
Rake::TestTask.new do |t|
  CrossRiverBank::Test.logger = Logger.new STDOUT
  CrossRiverBank::Test.logger.level = Logger::ERROR
  t.pattern ='test/**/test_*.rb'
end
