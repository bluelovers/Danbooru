#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

if ARGV[0] == "start"
  current = []
  
  240.times do
    current = `pgrep -f job_task_processor.rb`.scan(/\d+/)
    next if current.size == 0
    
    current.each do |pid|
      `kill -SIGTERM #{pid}`
    end
    
    sleep 5
  end

  if current.size > 0
    current.each do |pid|
      `kill -SIGKILL #{pid}`
    end
  end

  `psql danbooru -c "update job_tasks set status = 'pending' where task_type = 'calculate_tag_subscriptions'"`
end

Daemons.run(File.dirname(__FILE__) + "/job_task_processor.rb", :log_output => true, :dir => "../../log")
