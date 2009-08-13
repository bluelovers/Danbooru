#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

PoolUpdate.transaction do
  PoolUpdate.find_each do |update|
    i = 0
    update.post_ids = update.post_ids.split(" ").map do |x|
      i += 1
      "#{x} #{i}"
    end.join(" ")

    update.save
  end
end
