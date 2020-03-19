#!/usr/bin/ruby

Dir.glob(File.join('.', 'lib', '**', '*.rb'), &method(:require))

test = Test.new
test.main

