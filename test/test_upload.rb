# -*- coding: utf-8 -*-

lib = File.dirname(__FILE__)
$:.unshift lib unless $:.include?(lib)

require 'test/unit'
require 'helper'

class Upload < Test::Unit::TestCase
  def test_upload
    path = File.dirname(__FILE__) + '/paris.jpg'
    u = info = nil
    title = "Test Photo Title"
    description = "Test Photo Description"

    assert_nothing_raised(SmugRaw::FailedResponse) {
      @added_image_info = smugmug.upload_image(file, {:AlbumID => @added_album_info['AlbumID'],
                                                      :Caption => 'A Paris Church',
                                                      :})
    }
    @stderr.puts "upload_image result: " + @added_image_info.inspect
    # FIXME: check result
  end


#    title = "Titre de l'image testée"
#    description = "Ceci est la description de l'image testée"
    assert_nothing_raised {
      u = flickr.upload_photo path,
        :title => title,
        :description => description
    }

    assert_nothing_raised {
      info = flickr.photos.getInfo :photo_id => u.to_s
    }

    assert_equal title, info.title
    assert_equal description, info.description

    assert_nothing_raised {flickr.photos.delete :photo_id => u.to_s}
  end
end

