#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

if ARGV[0] == "start"
  current = []
  
  30.times do
    current = `pgrep -f job_task_processor.rb`.scan(/\d+/)
    next if current.size == 0
    
    current.each do |pid|
      `kill -SIGTERM #{pid}`
    end
    
    sleep 1
  end

  if current.size > 0
    current.each do |pid|
      `kill -SIGKILL #{pid}`
    end
  end

  `psql danbooru -h dbserver -c "update job_tasks set status = 'pending' where status IN ('processing', 'error')"`
end

Daemons.run(File.dirname(__FILE__) + "/job_task_processor.rb", :log_output => true, :dir => "../../log")
