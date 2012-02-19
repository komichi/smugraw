#!/usr/bin/env ruby

require 'rubygems'
require './smugraw'
require './smugraw/env'
require 'set'
require 'logger'
require 'getoptlong'

$verbose = false
$no_confirm = false
$background = false
$output = nil
$output_file = nil

$log = Logger.new $stderr
$log.level = $verbose ? Logger::DEBUG : Logger::ERROR

# TODO: add search parameters to select only certain albums 
#       (by date or name, at least)

def usage
  $stderr.puts(<<EOF)
smugmug_dump.rb [--help|-h] [--verbose|-v] [--output|-o <file>]

NOTE: this script dumps all the albums selected to a JSON file
      suitable for use with smug2flickr.rb.
EOF
  exit
end

def chat(s)
  $stderr.puts s if $verbose && (! $background) && (! $stderr.closed?)
end

opts = GetoptLong.new(
         [ '--help',            '-h', GetoptLong::NO_ARGUMENT ],
         [ '--verbose',         '-v', GetoptLong::NO_ARGUMENT ],
         [ '--noconfirm',       '-n', GetoptLong::NO_ARGUMENT ],
         #[ '--background',      '-b', GetoptLong::NO_ARGUMENT ],
         [ '--output',          '-o', GetoptLong::REQUIRED_ARGUMENT ])

opts.each do |opt, arg|
  case opt
    when '--help': usage
    when '--verbose': $verbose = true
    when '--noconfirm': $no_confirm = true
    #when '--background': $background = true
    when '--output': $output_file = arg
  end
end

$log.level = $verbose ? Logger::DEBUG : Logger::ERROR

begin
  $output = $output_file ? File.open($output_file, 'w') : $stdout
rescue Exception => e
  $stderr.puts "open of #{$output_file} failed: " + e
  exit
end

albums = [ ]
images = [ ]
usedCategories = Set.new
usedSubcategories = Set.new

# prompts the user to confirm the album name
def confirm_inclusion(album)
  begin
    ret = false
    category = album['Category'] ? album.Category.Name.to_s : ''
    subCategory = album['SubCategory'] ? ' / ' + album.SubCategory.Name.to_s : ''
    $stderr.print "Include: " + category + subCategory + ' / ' + album.Title + ' ? (y|N|x) '
    response = $stdin.gets
    return nil if (response =~ /^x/i)
    return (response =~ /^y/i) ? true : false
  rescue Exception => e
    return nil
  end
end

def detach
  $stdin.close
  $stdout.close unless $output_file == $stdout
  $stderr.close
end

# run through all the albums to figure out which ones to gather
chat "confirming which albums to include ... "
smugmug_albums = [ ]

if $no_confirm
  smugmug_albums = smugmug.albums.get
else
  smugmug.albums.get.each { |album|
    $log.debug album.to_s unless $stderr.closed?
    confirmed = confirm_inclusion(album)
    break if confirmed.nil?
    smugmug_albums.push album if confirmed
  }
end

#if $background
#  fork || exit 
#  detach
#end

# now actually gather the info
chat "grabbing album data ... "
smugmug_albums.each { |album|
  usedCategories.add({ :Name => album.Category['Name'], 
                       :id   => album.Category['id'] }) if album['Category']
  usedSubcategories.add({ :Name     => album.SubCategory['Name'],
                          :id       => album.SubCategory['id'],
                          :Category => album.Category['Name'] }) if album['SubCategory']
  album_images = smugmug.images.get(:AlbumID => album.id, :AlbumKey => album.Key)
  album_images.Images.each { |image|
    image = smugmug.images.getInfo(:ImageID => image.id, :ImageKey => image.Key).to_hash
    $log.debug image.inspect unless $stderr.closed?
    # NOTE: without spaces, it seems the JSON parser cannot find the kanji byte-order-mark
    #   however
    #   state = JSON::Ext::Generator::State.new({:space => ' ', :space_before => ' '})
    #       and JSON.generate(image, state) does NOT work
    #   so we use pretty print
    images.push image
  }
  albums.push album.to_hash
}

# dump the data out
$output.puts '{ "Categories": ' + JSON.pretty_generate(usedCategories.to_a).to_s + ', '
$output.puts '  "SubCategories": ' + JSON.pretty_generate(usedSubcategories.to_a).to_s + ', '
$output.puts '  "Albums": ' + JSON.pretty_generate(albums) + ','
$output.puts '  "Images": ' + JSON.pretty_generate(images) + ' }'

