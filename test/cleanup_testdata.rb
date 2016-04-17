# encoding: utf-8
# rubocop:disable Lint/HandleExceptions:

#
# DANGEROUS!! DO NOT RUN THIS ON YOUR PRODUCTION SYSTEM
#
# the test cases nromally does cleanup after themselves. In some cases, the test case execution is 
# interrupted# eitehr due to test failure or user intervention, the test data remaining in the 
# system can cause next test execution to fail. When this happens, run this script to cleanup 
# the data, then run the test cases again
#
require 'helper'

# TODO: write logic to cleanup data created by test cases

#
# this method cleans up data created by test_customers.rb
#
def cleanup_test_custoemrs 
  mobile_no = '13911223366'
  app_client.customer.find(mobile: mobile_no)['rows'].each do |c|
    id = c['id']
    puts "Deleting customer #{id}"
    begin
      app_client.customer.delete(id)
    rescue RestClient::InternalServerError
    end
  end
end

#
# this method cleans up data created by test_channel_account.rb
#
def cleanup_channel_accounts
  cust_id = 3021200
  app_client.channel_account.find(userId: "u#{cust_id}").each do |c|
    id = c['id']
    puts "Deleting channel account #{id}"
    begin
      app_client.channel_account.delete(id)
    rescue RestClient::InternalServerError
    end
  end
end

cleanup_test_custoemrs
cleanup_channel_accounts
