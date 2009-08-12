#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

Pool.transaction do
  Pool.find_each do |pool|
    pool.save
  end
end
