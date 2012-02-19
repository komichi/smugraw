#!/usr/bin/env ruby

require 'rubygems'
require './smugraw'

smugmug.access_token = "4cc3ad51196b9f1087d156baefb1c827"
smugmug.access_secret = "f559305e54c83748a9f6c3f49bbc8371943224239f063b54f055971e29d12fcf"

smugmug.albums.get.each { |album|
  puts album.inspect
#  $stderr.puts 'album id: ' + album['id'].inspect
#  $stderr.puts 'album id: ' + album.id.inspect
  photos = smugmug.images.get({ :AlbumID => album.id, :AlbumKey => album.Key })
  $stderr.puts 'album id: ' + album.id.inspect + ' photos: ' + photos.inspect
  album_comments = smugmug.albums.comments.get({ :AlbumID => album.id, :AlbumKey => album.Key })
  $stderr.puts 'album comments: ' + album_comments.inspect
  album_info = smugmug.albums.getInfo(:AlbumID => album.id, :AlbumKey => album.Key)
  $stderr.puts 'album info: ' + album_info.inspect
  unless photos.nil? || photos.Images.size == 0
    photo_comments = smugmug.images.comments.get({ :ImageID => photos.Images[0].id, :ImageKey => photos.Images[0].Key })
    $stderr.puts 'photo[0] comments: ' + photo_comments.inspect
  end
}

