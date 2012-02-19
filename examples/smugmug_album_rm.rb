#!/usr/bin/env ruby

require 'rubygems'
require './smugraw'
require 'logger'

smugmug.access_token = "4cc3ad51196b9f1087d156baefb1c827"
smugmug.access_secret = "f559305e54c83748a9f6c3f49bbc8371943224239f063b54f055971e29d12fcf"

log = Logger.new $stderr
log.level = Logger::DEBUG

$verbose = false

ARGV.each { |albumID|
  print "Delete album ID " + albumID + "? "
  line = $stdin.readline
  if line =~ /^y/i: smugmug.albums.delete :AlbumID => albumID
  else; puts "skipped"; end
}

