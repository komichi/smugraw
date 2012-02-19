lib = File.expand_path('../../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'smugraw'

SmugRaw.api_key = ENV['SMUGRAW_API_KEY']
SmugRaw.shared_secret = ENV['SMUGRAW_SHARED_SECRET']
#SmugRaw.secure = true

smugmug.access_token = ENV['SMUGRAW_ACCESS_TOKEN']
smugmug.access_secret = ENV['SMUGRAW_ACCESS_SECRET']

