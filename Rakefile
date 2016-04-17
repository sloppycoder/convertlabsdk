# encoding: utf-8

task :clean do
  rm_rf "coverage"
  rm_rf "dev.sqlite3"
  rm_rf "test.sqlite3"
  rm_rf "pkg"
  rm_rf "convertlabsdk.gem"
end

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... 
  # see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = 'convertlabsdk'
  gem.homepage = 'http://github.com/sloppycoder/convertlabsdk'
  gem.license = 'Commercial'
  gem.summary = 'ConvertLab SDK'
  gem.description = %(Library to facilitate synchronizing your application object with ConvertLab cloud services)
  gem.email = 'guru.lin@gmail.com'
  gem.authors = ['Li Lin']
  # dependencies defined in Gemfile
end

# do not publish to rubygems.org just yet
# Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

desc 'Code coverage detail'
task :simplecov do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].execute
end

require 'rubocop/rake_task'
desc 'Run RuboCop on the lib and test directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ['lib/**/*.rb', 'test/**/*.rb']
  # only show the files with failures
  # task.formatters = ['files']
  # don't abort rake on failure
  task.fail_on_error = false
end

require 'standalone_migrations'
StandaloneMigrations::Tasks.load_tasks

task default: :test

# TODO: restore rdoc later

# require 'rdoc/task'
# Rake::RDocTask.new do |rdoc|
#   version = File.exist?('VERSION') ? File.read('VERSION') : ''

#   rdoc.rdoc_dir = 'rdoc'
#   rdoc.title = 'convertlabsdk #{version}'
#   rdoc.rdoc_files.include('README*')
#   rdoc.rdoc_files.include('lib/**/*.rb')
# end
