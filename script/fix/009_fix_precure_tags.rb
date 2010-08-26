#!/usr/bin/env ruby
require File.dirname(__FILE__) + "/../../config/environment"

ActiveRecord::Base.connection.execute("SET statement_timeout = 0")

tags = "fresh_precure! futari_wa_precure futari_wa_precure_splash_star heartcatch_precure! precure_all_stars yes!_precure_5 precure".scan(/\S+/).inject({}) do |h, x|
  puts "Searching for #{x}"
  h[x] = Tag.find_by_name(x).id
  h
end

puts "Deleting implications"
TagImplication.first(:conditions => ["predicate_id = ? and consequent_id = ?", tags["fresh_precure!"], tags["futari_wa_precure"]]).destroy
TagImplication.first(:conditions => ["predicate_id = ? and consequent_id = ?", tags["futari_wa_precure_splash_star"], tags["futari_wa_precure"]]).destroy
TagImplication.first(:conditions => ["predicate_id = ? and consequent_id = ?", tags["heartcatch_precure!"], tags["futari_wa_precure"]]).destroy
TagImplication.first(:conditions => ["predicate_id = ? and consequent_id = ?", tags["precure_all_stars"], tags["futari_wa_precure"]]).destroy
TagImplication.first(:conditions => ["predicate_id = ? and consequent_id = ?", tags["yes!_precure_5"], tags["futari_wa_precure"]]).destroy

puts "Deleting futari_wa_precure"
Tag.mass_edit("futari_wa_precure", "", 1, "127.0.0.1")

puts "Creating futari_wa_precure_(1st) alias"
TagAlias.create(:name => "futari_wa_precure_(1st)", :alias => "futari_wa_precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating fresh_precure! implication"
TagImplication.create(:predicate => "fresh_precure!", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating futari_wa_precure implication"
TagImplication.create(:predicate => "futari_wa_precure", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating futari_wa_precure_splash_star implication"
TagImplication.create(:predicate => "futari_wa_precure_splash_star", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating heartcatch_precure! implication"
TagImplication.create(:predicate => "heartcatch_precure!", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating precure_all_stars implication"
TagImplication.create(:predicate => "precure_all_stars", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")

puts "Creating yes!_precure_5 implication"
TagImplication.create(:predicate => "yes!_precure_5", :consequent => "precure", :is_pending => true).approve(1, "127.0.0.1")
