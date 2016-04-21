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

# credit goes to https://gist.github.com/schickling/6762581
require 'active_record'
require 'yaml'
namespace :db do
  config = YAML::load(File.open('db/config.yml'))
  db_config = config[ENV['RAILS_ENV'] || 'development']

  desc 'Migrate the database'
  task :migrate do
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Migrator.migrate('db/migrate/')
    Rake::Task['db:schema'].invoke
    puts 'Database migrated.'
  end

  desc 'Create a db/schema.rb file that is portable against any DB supported by AR'
  task :schema do
    ActiveRecord::Base.establish_connection(db_config)
    require 'active_record/schema_dumper'
    filename = 'db/schema.rb'
    File.open(filename, 'w:utf-8') do |file|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
    end
  end
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ''
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "convertlabsdk #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task default: :test
