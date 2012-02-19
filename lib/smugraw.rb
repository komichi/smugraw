require 'json'
require 'smugraw/oauth'
require 'smugraw/request'
require 'smugraw/response'
require 'smugraw/api'

module SmugRaw
  VERSION='0.1.0'
  USER_AGENT = "SmugRaw/#{VERSION}"
end

# Use this to access the smugmug API easily. You can type directly the smugmug requests as they are described on the smugmug website.
#  require 'smugraw'
#
#  recent_photos = smugmug.photos.getRecent
#  puts recent_photos[0].title
def smugmug; $smugmugraw ||= SmugRaw::SmugMug.new end

