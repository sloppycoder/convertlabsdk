# encoding: utf-8
require 'find'
require File.expand_path('../lib/convertlabsdk/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'convertlabsdk'
  s.version = ConvertLab::VERSION

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib']
  s.authors = ['Li Lin']
  s.date = '2016-04-22'
  s.description = 'Library to facilitate synchronizing your application object with ConvertLab cloud services'
  s.email = 'guru.lin@gmail.com'
  # s.homepage = 'http://github.com/sloppycoder/convertlabsdk'
  s.licenses = ['Commercial']
  s.rubygems_version = '2.4.5.1'
  s.summary = 'ConvertLab SDK'

  s.extra_rdoc_files = %w(
    LICENSE.txt
    README.md
  )

  s.files = %w(
    Gemfile
    Gemfile.lock
    Rakefile
    convertlabsdk.gemspec
  )

  %w(lib test db config).each do |path|
    Find.find(path) { |f| s.files << f if FileTest.file?(f) && File.basename(f)[0] != '.' }
  end

  if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') 
    s.add_runtime_dependency('rest-client', ['~> 1.8'])
    s.add_runtime_dependency('activerecord', ['~> 4.2'])
    s.add_development_dependency('minitest', ['>= 0'])
    s.add_development_dependency('minitest-profile', ['>= 0'])
    s.add_development_dependency('minitest-reporters', ['>= 0'])
    s.add_development_dependency('yard', ['~> 0.8'])
    s.add_development_dependency('bundler', ['~> 1.0'])
    s.add_development_dependency('simplecov', ['>= 0'])
    s.add_development_dependency('rubocop', ['>= 0'])
    s.add_development_dependency('webmock', ['>= 0'])
    s.add_development_dependency('vcr', ['~> 3.0'])
  end
end
