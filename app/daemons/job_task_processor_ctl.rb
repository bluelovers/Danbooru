#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
require 'postgres'

dbhost = ENV["DB_HOST"] || "localhost"
dbname = ENV["DB_NAME"] || "danbooru"

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

  db = PGconn.connect(db_host, nil, nil, nil, db_name)
  db.exec("UPDATE job_tasks SET status = 'pending' WHERE status IN ('processing', 'error')")
end

Daemons.run(File.dirname(__FILE__) + "/job_task_processor.rb", :log_output => true, :dir => "../../log")
