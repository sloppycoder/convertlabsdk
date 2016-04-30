# encoding: utf-8

module TestData
  extend self

  def data
    @data ||= load_testdata
  end

  def intervals
    data.collect { |row| row['last_update'] }.uniq.sort
  end

  def order_details(day)
    data.select { |r| r['last_update'] == day }
  end

  def load_testdata
    require 'csv'
    csv_source = %(
orderNumber,isMember,membershipLevel,membershipNo,mobile,name,last_update
10001,true,silver,A1234,139112233,guru lin,2016-01-01
10002,true,gold,A1111,133123123,stefan liu,2016-01-01
10001,true,gold,A1234,139112233,guru lin,2016-01-02
10003,true,platinum,A8888,133333333,jack ma,2016-01-02
)
    t = []
    CSV.parse(csv_source, skip_blanks: true, headers: true) do |row|
      t << row.to_hash
    end
    t
  end
end
