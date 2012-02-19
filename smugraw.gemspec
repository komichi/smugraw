# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'smugraw'

Gem::Specification.new do |s|
  s.summary = "SmugMug library with a syntax close to the syntax described on http://www.smugmug.com/hack"
  s.name = "smugraw"
  s.author = "John Lane"
  s.email =  "johnrlane+smugmug@gmail.com"
  s.homepage = "http://komichi.github.com/smugraw/"
  s.version = SmugRaw::VERSION
  s.files = Dir["examples/*.rb"] + Dir["test/*.rb"] + Dir["lib/**/*.rb"] + %w{smugraw_rdoc.rb LICENSE README.rdoc rakefile}
end

