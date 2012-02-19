#!/usr/bin/env ruby

# -*- coding: utf-8 -*-

lib = File.dirname(__FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rubygems'
require 'test/unit'
require 'helper'
require 'logger'

SmugRaw.api_key = '7AAXV3xbB39nc9hzw5PpWO0uf2HyPLpl'.freeze # FIXME: remove
SmugRaw.shared_secret = '3c701c118859bfeb03687fc53bf5b60b'.freeze # FIXME: remove

smugmug.access_token = "4cc3ad51196b9f1087d156baefb1c827"
smugmug.access_secret = "f559305e54c83748a9f6c3f49bbc8371943224239f063b54f055971e29d12fcf"

class Basic < Test::Unit::TestCase
  @@log = Logger.new($stderr)
  @@log.level = Logger::ERROR #Logger::DEBUG
  @@added_album_info = nil
  @@added_image_info = nil
  @@existing_album_info = { :AlbumID => '21077070', :AlbumKey => '4FC2WC', :Description => 'Test Gallery Description' }
  @@existing_image_info = { :ImageID => '1676850444', :ImageKey => 'QJCZP89' }
  @@existing_image_exif = { 'File name' => '374743_10151135961465184_787290183_22064743_901818040_n.jpg',
                            'File size' => '92445' }
  @@existing_album_comment = { 'Date' => '', 'Rating' => '', 'Text' => '', 'Type' => '' }
  @@existing_image_comment = { 'Date' => '', 'Rating' => '', 'Text' => '', 'Type' => '' }
  @@existing_user_info = { 'NickName' => 'komichi', 'URL' => 'http://komichi.smugmug.com' }

  # NOTE: SmugMug has some issues with reflection
  #       - 1.3.X doesn't report all methods so this library doesn't work at all
  #       - 1.2.X reports *most* methods, but some are missing (e.g., logout)
  def test_request
    @@log.debug 'test_request'
    smugmug_objects = %w{
       albums albumtemplates auth categories communities
       coupons family fans featured friends images login
       printmarks products service sharegroups styles
       subcategories themes users watermarks reflection
    }
    assert_equal SmugRaw::SmugMug.smugmug_objects, smugmug_objects
    smugmug_objects.each {|o|
      assert_respond_to  smugmug, o
      assert_kind_of SmugRaw::Request, eval("smugmug." + o)
    }
  end

  def test_known
    @@log.debug 'test_known'
    known_methods = %w{smugmug.albums.applyWatermark
                       smugmug.albums.changeSettings
                       smugmug.albums.comments.add
                       smugmug.albums.comments.get
                       smugmug.albums.create
                       smugmug.albums.delete
                       smugmug.albums.get
                       smugmug.albums.getInfo
                       smugmug.albums.getStats
                       smugmug.albums.removeWatermark
                       smugmug.albums.reSort
                       smugmug.albumtemplates.changeSettings
                       smugmug.albumtemplates.create
                       smugmug.albumtemplates.delete
                       smugmug.albumtemplates.get
                       smugmug.auth.checkAccessToken
                       smugmug.auth.getAccessToken
                       smugmug.auth.getRequestToken
                       smugmug.categories.create
                       smugmug.categories.delete
                       smugmug.categories.get
                       smugmug.categories.rename
                       smugmug.communities.get
                       smugmug.coupons.create
                       smugmug.coupons.get
                       smugmug.coupons.getInfo
                       smugmug.coupons.modify
                       smugmug.coupons.restrictions.albums.add
                       smugmug.coupons.restrictions.albums.remove
                       smugmug.family.add
                       smugmug.family.get
                       smugmug.family.remove
                       smugmug.family.removeAll
                       smugmug.fans.get
                       smugmug.featured.albums.get
                       smugmug.friends.add
                       smugmug.friends.get
                       smugmug.friends.remove
                       smugmug.friends.removeAll
                       smugmug.images.applyWatermark
                       smugmug.images.changePosition
                       smugmug.images.changeSettings
                       smugmug.images.collect
                       smugmug.images.comments.add
                       smugmug.images.comments.get
                       smugmug.images.crop
                       smugmug.images.delete
                       smugmug.images.get
                       smugmug.images.getEXIF
                       smugmug.images.getInfo
                       smugmug.images.getStats
                       smugmug.images.getURLs
                       smugmug.images.removeWatermark
                       smugmug.images.rotate
                       smugmug.images.uploadFromURL
                       smugmug.images.zoomThumbnail
                       smugmug.login.anonymously
                       smugmug.login.withHash
                       smugmug.login.withPassword
                       smugmug.logout
                       smugmug.printmarks.create
                       smugmug.printmarks.delete
                       smugmug.printmarks.get
                       smugmug.printmarks.getInfo
                       smugmug.printmarks.modify
                       smugmug.products.get
                       smugmug.service.ping
                       smugmug.sharegroups.albums.add
                       smugmug.sharegroups.albums.get
                       smugmug.sharegroups.albums.remove
                       smugmug.sharegroups.create
                       smugmug.sharegroups.delete
                       smugmug.sharegroups.get
                       smugmug.sharegroups.getInfo
                       smugmug.sharegroups.modify
                       smugmug.styles.getTemplates
                       smugmug.subcategories.create
                       smugmug.subcategories.delete
                       smugmug.subcategories.get
                       smugmug.subcategories.getAll
                       smugmug.subcategories.rename
                       smugmug.themes.get
                       smugmug.users.getInfo
                       smugmug.users.getStats
                       smugmug.users.getTree
                       smugmug.watermarks.changeSettings
                       smugmug.watermarks.create
                       smugmug.watermarks.delete
                       smugmug.watermarks.get
                       smugmug.watermarks.getInfo
    }
    found_methods = smugmug.reflection.getMethods
    assert_instance_of SmugRaw::ResponseList, found_methods
    assert_equal known_methods.sort, found_methods.to_a.sort
  end

  # albums.create (smugmug)
  def test_AAA_album_create
    @@log.debug 'test_AAA_album_create'
    result = nil
    assert_nothing_raised(SmugRaw::FailedResponse) {
      result = smugmug.albums.create(:Title => 'Test Album 1', :Description => 'Another Test Album')
    }
    assert_not_nil(result)
    @@log.debug "album.create result: " + result.inspect
    @@added_album_info = { 'AlbumID' => result['id'].to_s, 'AlbumKey' => result['Key'] }
  end

  # image upload (smugmug)
  def test_AAA_image_upload
    file = File.dirname(__FILE__) + '/single_pixel.jpg'
    @@log.debug 'test_image_upload using file ' + file.to_s
    result = nil
    assert_not_nil(@@added_album_info)
    assert_nothing_raised(SmugRaw::FailedResponse) {
      result = smugmug.upload_image(file, { 'AlbumID' => @@added_album_info['AlbumID'],
                                            'Caption' => 'Fuji Q',
                                            'Keywords' => 'test, photo'})
    }
    @@log.debug "upload_image result: " + result.inspect
    @@added_image_info = { 'ImageID' => result['id'].to_s, 'ImageKey' => result['Key'] } 
  end

  # person info check (smugmug)
  def existing_user_check(user)
    @@log.debug 'existing_user_check'
    #assert_equal 'John Lane', user.DisplayName
    assert_equal @@existing_user_info['NickName'], user['NickName']
    assert_equal @@existing_user_info['URL'], user['URL']
  end

  # users.getInfo (smugmug)
  def test_users_getInfo
    @@log.debug 'test_users_getInfo'
    info = nil
    assert_nothing_raised(SmugRaw::FailedResponse) {
      info = smugmug.users.getInfo(:NickName => @@existing_user_info['NickName'])
    }
    @@log.debug 'users.getInfo result: ' + info.inspect
    existing_user_check(info)
  end

  # images.getInfo
  def test_images_getInfo
    @@log.debug 'test_images_getInfo'
    info = nil
    assert_not_nil(@@existing_image_info)
    assert_nothing_raised(SmugRaw::FailedResponse) {
      info = smugmug.images.getInfo(@@existing_image_info)
    }
    @@log.debug 'images.getInfo result: ' + info.inspect
  end

  # images.getEXIF (smugmug)
#  def test_images_getEXIF
#    @@log.debug 'test_images_getEXIF'
#    result = nil
#    assert_not_nil(@@existing_image_info)
#    assert_nothing_raised(SmugRaw::FailedResponse) {
#      result = smugmug.images.getEXIF(@@existing_image_info)
#    }
#    @@log.debug 'images.getEXIF result: ' + result.inspect
#    assert_not_nil result
#    assert_equal @@existing_image_exif['File name'], result['File name']
#    assert_equal @@existing_image_exif['File size'], result['File size']
#  end

  # images.getURLs (smugmug)
  def test_images_getURLs
    result = nil
    @@log.debug 'test_images_getURLs'
    assert_not_nil(@@existing_image_info)
    assert_nothing_raised(SmugRaw::FailedResponse) {
      result = smugmug.images.getURLs(@@existing_image_info)
    }
    @@log.debug 'images.getURLs result: ' + result.inspect
    assert_not_nil result
    # FIXME: add assertions for URLs
    # assert_equal info.URL, FOO
  end

  # images.comments (smugmug)
  def test_images_comments_get
    @@log.debug 'test_images_comments_get'
    assert_not_nil(@@existing_album_info)
    info = smugmug.images.comments.get(@@existing_image_info)
    @@log.debug 'images.comments.get result: ' + info.inspect
    assert_equal info.Comments.size, 1
    # FIXME: add comparison
  end

  # images.comments (smugmug)
  def test_albums_comments_get
    @@log.debug 'test_albums_comments_get'
    result = nil
    assert_not_nil(@@existing_album_info)
    info = smugmug.albums.comments.get(@@existing_album_info)
    @@log.debug 'albums.comments.get result: ' + info.inspect
    assert_equal info.Comments.size, 1
    # FIXME: add comparison
  end

  # images.delete delete the images (smugmug)
  def test_zzz_images_delete
    @@log.debug 'test_zzz_images_delete'
    result = nil
    assert_not_nil(@@added_image_info)
    assert_nothing_raised(SmugRaw::FailedResponse) {
      result = smugmug.images.delete(@@added_image_info)
    }
  end

  # delete the album (smugmug)
  def test_zzz_album_delete
    @@log.debug 'test_zzz_album_delete'
    result = nil
    assert_not_nil(@@added_album_info)
    assert_nothing_raised(SmugRaw::FailedResponse) {
      result = smugmug.albums.delete(@@added_album_info)
    }
  end

#  def test_list
#    list = smugmug.photos.getRecent :per_page => '10'
#    assert_instance_of SmugRaw::ResponseList, list
#    assert_equal(list.size, 10)
#  end

#  def photo(info)
#    assert_equal "3839885270", info.id
#    assert_equal "41650587@N02", info.owner
#    assert_equal "6fb8b54e06", info.secret
#    assert_equal "2485", info.server
#    assert_equal 3, info.farm
#    assert_equal "cat", info.title
#    assert_equal 1, info.ispublic
#  end

#  # favorites
#  def test_favorites_getPublicList
#    list = smugmug.favorites.getPublicList :user_id => "41650587@N02"
#    assert_equal 1, list.size
#    assert_equal "3829093290", list[0].id
#  end

#  # groups
#  def test_groups_getInfo
#    info = smugmug.groups.getInfo :group_id => "51035612836@N01"
#    assert_equal "51035612836@N01", info.id
#    assert_equal "SmugMug API", info.name
#  end

#  def test_groups_search
#    list = smugmug.groups.search :text => "SmugMug API"
#    assert list.any? {|g| g.nsid == "51035612836@N01"}
#  end

#  # people
#  def test_people_findByEmail
#    user = smugmug.people.findByEmail :find_email => "smugraw@yahoo.com"
#    people user
#  end

#  def test_people_findByUsername
#    user = smugmug.people.findByUsername :username => "ruby_smugraw"
#    people user
#  end

#  def test_people_getPublicGroups
#    groups = smugmug.people.getPublicGroups :user_id => "41650587@N02"
#    assert groups.to_a.empty?
#  end

#  def test_people_getPublicPhotos
#    info = smugmug.people.getPublicPhotos :user_id => "41650587@N02"
#    assert_equal 1, info.size
#    assert_equal "1", info.total
#    assert_equal 1, info.pages
#    assert_equal 1, info.page
#    photo(info[0])
#  end

#  # tags
#  def test_tags_getListPhoto
#    tags = smugmug.tags.getListPhoto :photo_id => "3839885270"
#    assert_equal 2, tags.tags.size
#    assert_equal "3839885270", tags.id
#    assert_equal %w{cat pet}, tags.tags.map {|t| t.to_s}.sort
#  end

#  def test_photos_search
#    info = smugmug.photos.search :user_id => "41650587@N02"
#    photo info[0]
#  end

#  # urls
#  def test_getURLs
#    info = smugmug.urls.getGroup :group_id => "51035612836@N01"
#    assert_equal "51035612836@N01", info.nsid
#    assert_equal "http://www.flickr.com/groups/api/", info.url
#  end

#  def test_tags_getListUser
#    tags =  smugmug.tags.getListUser :user_id => "41650587@N02"
#    assert_equal "41650587@N02", tags.id
#    assert_equal %w{cat pet}, tags.tags.sort
#  end

#  def test_urls_getUserPhotos
#    info = smugmug.images.getInfo
#    info = smugmug.urls.getUserPhotos :user_id => "41650587@N02"
#    assert_equal "41650587@N02", info.nsid
#    assert_equal "http://www.flickr.com/photos/41650587@N02/", info.url
#  end

#  def test_urls_getUserProfile
#    info = smugmug.urls.getUserProfile :user_id => "41650587@N02"
#    assert_equal "41650587@N02", info.nsid
#    assert_equal "http://www.flickr.com/people/41650587@N02/", info.url
#  end

#  def test_urls_lookupGroup
#    info = smugmug.urls.lookupGroup :url => "http://www.flickr.com/groups/api/"
#    assert_equal "51035612836@N01", info.id
#    assert_equal "SmugMug API", info.groupname
#  end

#  def test_urls_lookupUser
#    info = smugmug.urls.lookupUser :url => "http://www.flickr.com/photos/41650587@N02/"
#    assert_equal "41650587@N02", info.id
#    assert_equal "ruby_smugraw", info.username
#  end

#  def test_urls
#    id = "3839885270"
#    info = smugmug.photos.getInfo(:photo_id => id)
#
#    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06.jpg", SmugRaw.url(info)
#    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_m.jpg", SmugRaw.url_m(info)
#    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_s.jpg", SmugRaw.url_s(info)
#    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_t.jpg", SmugRaw.url_t(info)
#    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_b.jpg", SmugRaw.url_b(info)
#
#    assert_equal "http://www.flickr.com/people/41650587@N02/", SmugRaw.url_profile(info)
#    assert_equal "http://www.flickr.com/photos/41650587@N02/", SmugRaw.url_photostream(info)
#    assert_equal "http://www.flickr.com/photos/41650587@N02/3839885270", SmugRaw.url_photopage(info)
#    assert_equal "http://www.flickr.com/photos/41650587@N02/sets/", SmugRaw.url_photosets(info)
#    assert_equal "http://flic.kr/p/6Rjq7s", SmugRaw.url_short(info)
#  end

#  def test_url_escape
#    result_set = nil
#    assert_nothing_raised {
#      result_set = smugmug.photos.search :text => "family vacation"
#    }
#    assert_operator result_set.total.to_i, :>=, 0
#
#    # Unicode tests
#    echo = nil
#    utf8_text = "Hélène François, €uro"
#    assert_nothing_raised {
#      echo = smugmug.test.echo :utf8_text => utf8_text
#    }
#    assert_equal echo.utf8_text, utf8_text
#  end
end

