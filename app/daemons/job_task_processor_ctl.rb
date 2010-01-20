#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
begin
  require 'pg'
rescue LoadError => e
  begin
    require 'postgres'
  rescue LoadError
    raise e
  end
end

DB_CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), '../../config/database.yml'))[ENV['RAILS_ENV'] || "development"]
db_host = DB_CONFIG['host'] || "localhost"
db_name = DB_CONFIG['database'] || "danbooru"
db_port = DB_CONFIG['port'] || nil
db_login = DB_CONFIG['username'] || "danbooru"
db_pass = DB_CONFIG['password'] || ""

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

  db = PGconn.connect(db_host, db_port, nil, nil, db_name, db_login, db_pass)
  db.exec("UPDATE job_tasks SET status = 'pending' WHERE status IN ('processing', 'error')")
end

Daemons.run(File.dirname(__FILE__) + "/job_task_processor.rb", :log_output => true, :dir => "../../log")
