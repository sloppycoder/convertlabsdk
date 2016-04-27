# encoding: utf-8

task :clean do
  %w(
    dev.sqlite3
    test.sqlite3
    pkg
    doc
    rdoc
    coverage
    gem_graph.png
  ).each do |path|
    rm_rf path, verbose: false
  end
end

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
  Bundler::GemHelper.install_tasks
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake'

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

def db_config
  env = ENV['RAILS_ENV'] || 'development'
  YAML::load(File.open('config/database.yml'))[env]
end

# credit goes to https://gist.github.com/schickling/6762581
require 'active_record'
require 'yaml'
namespace :db do

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

require 'yard'
YARD::Rake::YardocTask.new do |t|
end

task default: :test
