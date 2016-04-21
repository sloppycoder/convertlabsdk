# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: convertlabsdk 0.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "convertlabsdk"
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Li Lin"]
  s.date = "2016-04-21"
  s.description = "Library to facilitate synchronizing your application object with ConvertLab cloud services"
  s.email = "guru.lin@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".editorconfig",
    ".rubocop.yml",
    ".ruby-version",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "convertlabsdk.gemspec",
    "db/config.yml",
    "db/migrate/20160417052516_create_synced_objects.rb",
    "db/schema.rb",
    "examples/sync_customer/Gemfile",
    "examples/sync_customer/README.md",
    "examples/sync_customer/config.yml",
    "examples/sync_customer/db/migrate/20160417052516_create_synced_objects.rb",
    "examples/sync_customer/db/schema.rb",
    "examples/sync_customer/sync_customer.rb",
    "lib/convertlabsdk.rb",
    "test/cleanup_testdata.rb",
    "test/helper.rb",
    "test/test_access_token.rb",
    "test/test_channel_account.rb",
    "test/test_convertlabsdk.rb",
    "test/test_customer.rb",
    "test/test_customer_event.rb",
    "test/test_sync_api.rb",
    "test/test_synced_object.rb",
    "test/vcr_cassettes/test_access_token_01.yml",
    "test/vcr_cassettes/test_access_token_02.yml",
    "test/vcr_cassettes/test_access_token_03.yml",
    "test/vcr_cassettes/test_channel_account_01.yml",
    "test/vcr_cassettes/test_channel_account_02.yml",
    "test/vcr_cassettes/test_channel_account_03.yml",
    "test/vcr_cassettes/test_customer_01.yml",
    "test/vcr_cassettes/test_customer_02.yml",
    "test/vcr_cassettes/test_customer_event_01.yml"
  ]
  s.homepage = "http://github.com/sloppycoder/convertlabsdk"
  s.licenses = ["Commercial"]
  s.rubygems_version = "2.4.5.1"
  s.summary = "ConvertLab SDK"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-client>, ["~> 1.8"])
      s.add_runtime_dependency(%q<activerecord>, ["~> 4.2.5.1"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<minitest-profile>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 2.0.1"])
      s.add_development_dependency(%q<simplecov>, [">= 0"])
      s.add_development_dependency(%q<rubocop>, [">= 0"])
      s.add_development_dependency(%q<webmock>, [">= 0"])
      s.add_development_dependency(%q<vcr>, ["~> 3.0.1"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<byebug>, [">= 0"])
    else
      s.add_dependency(%q<rest-client>, ["~> 1.8"])
      s.add_dependency(%q<activerecord>, ["~> 4.2.5.1"])
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<minitest-profile>, [">= 0"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, ["~> 1.0"])
      s.add_dependency(%q<jeweler>, ["~> 2.0.1"])
      s.add_dependency(%q<simplecov>, [">= 0"])
      s.add_dependency(%q<rubocop>, [">= 0"])
      s.add_dependency(%q<webmock>, [">= 0"])
      s.add_dependency(%q<vcr>, ["~> 3.0.1"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<byebug>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-client>, ["~> 1.8"])
    s.add_dependency(%q<activerecord>, ["~> 4.2.5.1"])
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<minitest-profile>, [">= 0"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, ["~> 1.0"])
    s.add_dependency(%q<jeweler>, ["~> 2.0.1"])
    s.add_dependency(%q<simplecov>, [">= 0"])
    s.add_dependency(%q<rubocop>, [">= 0"])
    s.add_dependency(%q<webmock>, [">= 0"])
    s.add_dependency(%q<vcr>, ["~> 3.0.1"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<byebug>, [">= 0"])
  end
end

