#!/usr/bin/env ruby

require 'rubygems'
require './smugraw'
require './smugraw/env'
require 'flickraw'
require 'flickraw/env'
require 'date'
require 'getoptlong'
require 'fileutils'
require 'pp'

$be_quiet = false
$debug = false
$background = false
$skip_collections = false

def usage
  $stderr.puts(<<EOF)
smug2flickr.rb [--help|-h] [--quiet|-q] [--debug|-d] [--skipcols|-s]
               <smugmug dump file> <any jpg file>

NOTE: This script is to be used in conjunction with smugdump.rb to pull
      only the required albumdata down; it attempts to be smart about 
      moving SmugMug data to Flickr by:
      (1) mapping categories to collections
      (2) mapping subcategories to (sub)collections
      (3) mapping albums to photosets
      (4) inserting photosets in appropriate (sub)collections
      (5) utilizing md5 checksum (machine) tags to ensure non-dup uploads
          (if you haven't tagged your Flickr data, do so with the Flickraw
           utility script)
      However, if you have subcategories and albums within a given category
      this breaks because Flickr does not allow collections to be nexted with
      subcollections and photosets, so you'll need to sue the -s flag and
      handle this manually.
EOF
  exit
end

def die(s='error')
  $stderr.puts s
  exit 1
end

def log(s, nl="")
  unless $be_quiet
    $stderr.print s + nl
  end
end

def debug(s, nl="\n")
  if $debug
    $stderr.print s + nl
  end
end

opts = GetoptLong.new(
         [ '--help',            '-h', GetoptLong::NO_ARGUMENT ],
         [ '--quiet',           '-q', GetoptLong::NO_ARGUMENT ],
         [ '--skipcols',        '-s', GetoptLong::NO_ARGUMENT ],
        #[ '--background',      '-b', GetoptLong::NO_ARGUMENT ],
         [ '--debug',           '-d', GetoptLong::NO_ARGUMENT ])

opts.each do |opt, arg|
  case opt
    when '--help': usage
    when '--quiet': $be_quiet = true
    when '--debug': $debug = true
    when '--skipcols': $skip_collections = true
    #when '--background': $background = true
  end
end

def detach
  o = File.open('smug2flickr.log', 'w')
  i = File.open('/dev/zero', 'r')
  $stdin.close
  $stdout.close
  $stderr.close
  $stdin = i
  $stdout = o
  $stderr = o
end

# makes a hash tree from a flickr collections result 
#   based on collection name
# assumes no two categories have the same name at the same level
def make_flickr_coll_hash_tree(coll_tree, hash_tree)
  coll_tree.each { |coll|
    coll_title = coll['title']
    hash_tree[coll_title] = coll.is_a?(FlickRaw::Response) ? coll.to_hash : coll
    if coll['collection']
      coll_subtree = { }
      make_flickr_coll_hash_tree(coll['collection'], coll_subtree)
      hash_tree[coll_title]['collection'] = coll_subtree
    else
      hash_tree[coll_title]['collection'] = { }
    end
  }
end

die 'need a smugdump file!' unless smugdump_file = ARGV.shift
die 'need a jpeg file!' unless black_photo_file = ARGV.shift

# (0) load the black jpeg file (for some reason
#      Flickr requires a primary photo for each photoset
#      to already exist), therefore we add a single fake photo 
#      to be removed later (id'd by md5sum)
black_sha1sum = black_md5sum = black_photo_id = nil
log('doing default photo upload ... ')
begin
  File.open(black_photo_file) { |f|
    s = f.read
    black_sha1sum = Digest::SHA1.hexdigest s
    black_md5sum  = Digest::MD5.hexdigest s
  }
rescue Exception => e
  die 'failed to open black photo file! ' + e.to_s
end
begin
# if it's already there, use it
  debug('searching for photo with md5sum ' + black_md5sum)
  black_flickr_photos = flickr.photos.search(:tags => 'checksum:md5=' + black_md5sum)
  if black_flickr_photos && black_flickr_photos.size > 0
    black_photo_id = black_flickr_photos.first['id']
# otherwise upload it and add the checksums
  else
    black_photo_id = flickr.upload_photo(black_photo_file, 
                                         :title => 'Delete Me!',
                                         :description => 'This Photo is Not Here')
    flickr.photos.addTags({ :photo_id => black_photo_id,
                            :tags => 'checksum:md5=' + black_md5sum })
    flickr.photos.addTags({ :photo_id => black_photo_id,
                            :tags => 'checksum:sha1=' + black_sha1sum })
  end
rescue Exception => e
  die 'failed to upload black photo file!' + e.to_s
end
log('done', "\n")

# (1) load the smugmug dump file
smugdump_str = ''
smugdump = nil
#begin
log('loading smugmug data ... ')
File.open(smugdump_file) { |f| smugdump_str = f.read }
smugdump = JSON.parse(smugdump_str)
#rescue Exception => e
die 'failed to open SmugMug dump file: ' + e.to_s unless smugdump
#end
log('done', "\n")

# (2) sort the smugmug photos in order of the date they were taken
log('sorting images ... ')
smugdump['Images'].sort! { |a,b| DateTime.parse(a['Date']) <=> DateTime.parse(b['Date']) }
log('done', "\n")

# (3) get the flickr collections and turn it into a tree-based hash
#     (instead of an array of hashes)
log('reindexing Flickr collections ... ')
flickr_coll_tree = { }
make_flickr_coll_hash_tree(flickr.collections.getTree, flickr_coll_tree)
log('done', "\n")

debug("flickr collection tree is:\n")
pp flickr_coll_tree if $debug

# (4) create a Flickr collection for each SmugMug category,
#     unless one with the same name already exists,
#     recording the collection ids as we go
#begin
unless $skip_collections
  log('creating a Flickr collection for each category ...')
    smugdump['Categories'].each { |category|
      smugmug_category_title = category['Name']
      unless flickr_coll_tree[smugmug_category_title]
        flickr_coll = flickr.collections.create({ :title => smugmug_category_title,
                                                  :description => '' })
        flickr_coll_tree[smugmug_category_title] = flickr_coll
      end
      log('.')
    }
  #rescue Exception => e
  #die 'failed while creating a collection for each category: ' + e.to_s
  #end
  log(' done', "\n")
end

unless $skip_collections
  # (5) create a Flickr collection for each SmugMug subcategory, 
  #     unless one with the same name already exists,
  #     setting the created parent collection id's,
  #     recording the collection ids as we go
  #begin
  log('creating a Flickr collection for each SmugMug sub-category ...')
  smugdump['SubCategories'].each { |subcategory|
    smugmug_subcat_title = subcategory['Name']
    smugmug_subcat_parent_title = subcategory['Category']
    raise 'no Flickr parent collection ' + smugmug_subcat_parent_title +
          ' exists for SmugMug subcategory ' + smugmug_subcat_title unless
          flickr_coll_tree[smugmug_subcat_parent_title]
    flickr_coll_parent_id = flickr_coll_tree[smugmug_subcat_parent_title]['id']
    debug('looking for ' + smugmug_subcat_parent_title + ' / ' + smugmug_subcat_title, "\n")
    debug('flickr_coll_tree[' + smugmug_subcat_parent_title + '] is ' + flickr_coll_tree[smugmug_subcat_parent_title].inspect, "\n")
    unless flickr_coll_tree[smugmug_subcat_parent_title]['collection'] &&
           flickr_coll_tree[smugmug_subcat_parent_title]['collection'][smugmug_subcat_title]
      debug("didn't find " + smugmug_subcat_parent_title + ' / ' + smugmug_subcat_title, "\n")
      new_collection = flickr.collections.create({ :title => smugmug_subcat_title,
                                                   :description => '',
                                                   :parent_id => flickr_coll_parent_id })
      flickr_coll_tree[smugmug_subcat_parent_title]['collection'][smugmug_subcat_title] = new_collection.to_hash
    end
    log('.')
  }
  #rescue Exception => e
  #  die("failed to create subcategory: " + e.to_s)
  #end
  log(' done', "\n")
end

# (6) create a list of existing Flickr photosets,
#       to use later to ensure we don't create duplicates
flickr_photosets = { }
log('grabbing Flickr photosets ...')
#begin
flickr.photosets.getList.each { |photoset|
  raise "sorry (I'm dumb!) I can't handle duplicate " +
        "photoset names!" if flickr_photosets.has_key?(photoset['title'])
  flickr_photosets[photoset['title']] = photoset
}
#rescue Exception => e
# die "failed to obtain Flickr photoset list: " + e.to_s
#end
log(' done', "\n")

# (7) (a) create a Flickr photoset for each SmugMug album
#         unless one with the same name already exists,
#           recording the album ids as we go
#     (b) insert the Flickr photoset
#         if the SmugMug album is in a subcategory,
#           locate the Flickr collection corresponding to it,
#         else if the SmugMug album is in a category, 
#           locate the Flickr collection corresponding to it,
#         insert the photoset into the given collection if we found a collection
log('creating a Flickr photoset for each SmugMug album and adding it to its collection ... ')
smugmug_album_id_to_flickr_photoset_id = { }
smugdump['Albums'].each { |album|
  unless flickr_photosets.has_key?(album['Title'])
    log(album['Title'] + ' ')
    flickr_photosets[album['Title']] =
      flickr.photosets.create({ :title => album['Title'],
                                :description => '',
                                :primary_photo_id => black_photo_id })
  end
  flickr_photoset_id = flickr_photosets[album['Title']]['id']
# store the mapping between smugmug album and flickr photoset
  smugmug_album_id_to_flickr_photoset_id[album['id']] = flickr_photoset_id
  cat_name = album['Category'] ? album['Category']['Name'] : nil
  subcat_name = album['SubCategory'] ? album['SubCategory']['Name'] : nil
  debug("category name is #{cat_name.inspect}, subcategory name is #{subcat_name.inspect}")
  flickr_coll =
    if    subcat_name
      debug("looking for #{cat_name}, #{subcat_name}")
      flickr_coll_tree[cat_name]['collection'][subcat_name]
    elsif cat_name
      debug("looking for #{cat_name}")
      flickr_coll_tree[cat_name]
    else
      nil
    end
  debug("adding photoset #{album['Title']} to collection " + flickr_coll.inspect)
  flickr.collections.editSets({ :collection_id => flickr_coll['id'],
                                :photoset_ids => flickr_photoset_id,
                                :do_remove => 0 }) if flickr_coll && (! $skip_collections)
}
log('done', "\n")

# (8) upload the photos
#     for each photo:
#       bail if the photo is already on flickr
#       first download the photo,
#       then upload to flickr,
#       store the id,
#       if a given album does not have an id yet,
#       create the md5 / sha1 checksums
#       store the md5 / sha1 machine tags
#       store an id for the given album
#       for use in photo set creation
log('uploading photos ... ')
smugdump['Images'].each { |image|
  log('"' + image['Caption'] + '" ')
  image_file = "/tmp/" + image['id'].to_s + ".jpg"
# skip photos already on flickr
  flickr_photos = flickr.photos.search(:tags => 'checksum:md5=' + image['MD5Sum'])
  next if flickr_photos && flickr_photos.size > 0
# first download the photo,
  image_url = image['OriginalURL']
  begin
    log('Downloading Image ... ')
    `curl -# --location -o #{image_file} #{image_url}`
    raise Exception.new('download failed') unless $? == 0
# form the md5 and sha1 checksums
    sha1sum = md5sum = nil
    File.open(image_file) { |f|
      s = f.read
      sha1sum = Digest::SHA1.hexdigest s
      md5sum  = Digest::MD5.hexdigest s
    }
# upload the image
    image_title = ((! image['Caption']) || (image['Caption'].size == 0)) ? 'untitled' : image['Caption']
    log("Uploading Image (#{image_title} / #{image['id']}) ... ")
    flickr_photo_id = flickr.upload_photo(image_file,
                                          :title => image_title,
                                          :description => "")
# add the md5 and sha1 checksums as machine tags
    log('Setting MD5 Tag ... ')
    flickr.photos.addTags({ :photo_id => flickr_photo_id,
                            :tags => 'checksum:md5=' + md5sum })
    log('Done ... Setting SHA-1 Tag ... ')
    flickr.photos.addTags({ :photo_id => flickr_photo_id,
                            :tags => 'checksum:sha1=' + sha1sum })
    log('Done ... ')
# put the photo into its photoset
    log('Adding to PhotoSet ... ')
    flickr_photoset_id = smugmug_album_id_to_flickr_photoset_id[image['Album']['id']]
    flickr.photosets.addPhoto({ :photoset_id => flickr_photoset_id,
                                :photo_id => flickr_photo_id })
    log('Done', "\n")
  rescue Exception => e
    die("warning: failed to download photo #{image['id']} (caption #{image['Caption']}): " + e)
  ensure
    FileUtils.rm(image_file) if File.exists?(image_file)
  end
}
log(' done', "\n")

