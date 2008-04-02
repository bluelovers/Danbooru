if true
  f = (defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : "public") + "/javascripts/application.js"
  File.unlink(f) if File.exist?(f)
end
