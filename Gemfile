# encoding: utf-8

source 'http://rubygems.org'
# use alternative side because the official site could be partially 
# blocked by GFW inside China
# source 'https://ruby.taobao.org'

gemspec

group :development do
  gem 'rake', '~> 10.1'
  # jruby stuff
  gem 'activerecord-jdbcsqlite3-adapter', '>=0', platform: :jruby
  gem 'jdbc-sqlite3', '>=0', platform: :jruby
  gem 'pry', '>=0', platform: :jruby
  # MRI stuff
  gem 'sqlite3', '>=0', platform: [:ruby, :mingw_19]
  gem 'byebug', '>=0', platform: [:ruby_20, :ruby_21, :ruby_22, :mingw_20]
  gem 'debugger', '>=0', platform: [:ruby_19, :mingw_19]
  gem 'redcarpet', '>=0', platform: [:ruby_19, :mingw_19]
end
