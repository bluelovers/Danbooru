#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../config/environment'

log = Logger.new(File.open("#{RAILS_ROOT}/log/job_task_daemon.log", "a"))

$job_task_daemon_active = true

Signal.trap("TERM") do
  $job_task_daemon_active = false
  log.info "received sigterm"
end

while $job_task_daemon_active
  JobTask.execute_once

  i = 60
  while $job_task_daemon_active && i >= 0
    sleep 1
    i -= 1
  end
end

log.info "exiting"
