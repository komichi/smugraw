#!/usr/bin/env ruby

require 'rubygems'
require './smugraw'

methods = smugmug.methods

#username = 'johnrlane+smugmug@gmail.com'
#password = 'f00b@rage'

#smugmug.access_token = "4e22e195069879b9cbe78fa41d0fb0a7"
#smugmug.access_token = "bbe1c3554df999c77c044c9dbe06580e"
#smugmug.access_token = "deadbeef"
smugmug.access_token = "4cc3ad51196b9f1087d156baefb1c827"
smugmug.access_secret = "f559305e54c83748a9f6c3f49bbc8371943224239f063b54f055971e29d12fcf"

#f = smugmug.login.withPassword({:EmailAddress => username, :Password => password})
f = smugmug.communities.get #smugmug.service.ping

login = smugmug.auth.checkAccessToken
$stderr.puts "You are now authenticated as #{login.Auth.User.NickName} " +
             "login is #{login.inspect} " +
             "with token #{smugmug.access_token} " +
             "secret #{smugmug.access_secret} "

