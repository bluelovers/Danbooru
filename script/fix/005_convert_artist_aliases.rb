#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

Artist.all(:conditions => ["alias_id IS NULL"]).each do |artist|
  aliases = Artist.all(:conditions => ["alias_id = ?", artist.id])
  if aliases.any?
    artist.other_names = aliases.map(&:name).join(", ")
    artist.updater_id = 1
    artist.save
  end
end

Artist.update_all("alias_id IS NOT NULL", "is_active = false")
