require 'java'
require 'jbundler'

file = java.io.File.new('./Jarfile')
lines = org.apache.commons.io.FileUtils.readLines(file, "UTF-8")
puts lines

# file = Java::JavaIo::File.new('./Jarfile')
# lines = Java::OrgApacheCommonsIo::FileUtils.readLines(file, "UTF-8")
# puts lines