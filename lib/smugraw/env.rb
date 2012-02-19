require 'smugraw'

SmugRaw.api_key = ENV['SMUGRAW_API_KEY'] unless SmugRaw.api_key
SmugRaw.shared_secret = ENV['SMUGRAW_SHARED_SECRET'] unless SmugRaw.shared_secret
#SmugRaw.secure = true

smugmug.access_token = ENV['SMUGRAW_ACCESS_TOKEN'] unless smugmug.access_token
smugmug.access_secret = ENV['SMUGRAW_ACCESS_SECRET'] unless smugmug.access_secret

