require "rake/testtask"
require "bundler"

Bundler::GemHelper.install_tasks

Rake::TestTask.new do |t|
  t.libs << "test/unit"
  t.test_files = FileList["test/unit/test*.rb"]
  t.verbose = true
end

desc "Run tests"
task :default => :test
