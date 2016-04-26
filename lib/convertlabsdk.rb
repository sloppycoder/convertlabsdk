# encoding: utf-8
require 'convertlabsdk/version'
require 'convertlabsdk/logger'
require 'convertlabsdk/app_client'
require 'convertlabsdk/synced_object'

#
# this module contains SDK to access ConvertLab API and
# helpers to facilitate synchronization local application
# objects using such APIs
#
module ConvertLab
  MAX_SYNC_ERR ||= 10
  DUMMY_TIMESTAMP ||= Time.new('2000-01-01')
end
