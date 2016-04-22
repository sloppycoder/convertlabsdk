require 'byebug'
require 'active_support'
require 'active_support/core_ext'

def func(*args)
 o = args.extract_options!
 puts "-2-"
 puts args
 puts "-3-"
 puts o
end

def func2(options = {}) 
 o = options.dup
 o.delete(:a)
 puts o
end

aa = [ 1 , { x: 100, y:200 } ]
bb = { a:1, b:2}
byebug
z = 1
