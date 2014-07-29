require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.test_files = FileList['test/tc_*.rb']
  t.verbose = true
end

desc "Run unit tests"
task :default => :test
