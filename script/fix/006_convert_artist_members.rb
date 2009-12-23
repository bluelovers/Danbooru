#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

Artist.all(:conditions => ["group_id IS NOT NULL"]).each do |artist|
  artist.update_attributes(:group_name => Artist.find(artist.group_id).name, :updater_id => 1)
end
