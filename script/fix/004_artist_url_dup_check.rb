#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

urls = ArtistUrl.all(:conditions => ["normalized_url like ?", "%img.pixiv%"])
pixiv_handles = urls.map {|x| x.normalized_url[/img\/(.+?)\//, 1]}

handle_counts = pixiv_handles.inject({}) do |h, x|
  h[x] ||= 0
  h[x] += 1
  h
end

pixiv_handles_with_dupes = handle_counts.to_a.select {|x| x[1] > 1}.map {|x| x[0]}

pixiv_handles_with_dupes.each do |pixiv_handle|
  matches = ArtistUrl.all(:conditions => ["normalized_url like ?", "%img.pixiv.net/img/#{pixiv_handle}/%"])
  
  if matches.size == 2 && (matches[0].artist.alias_id == matches[1].artist_id || matches[1].artist.alias_id == matches[0].artist_id)
    next
  end
  
  if matches.size == 2 && (matches[0].artist_id == matches[1].artist_id)
    next
  end
  
  matches.each do |match|
    puts "#{match.artist_id},#{match.artist.alias_id},#{match.artist.is_active},#{match.artist.name},#{match.normalized_url}"
  end
  puts "---"
end
