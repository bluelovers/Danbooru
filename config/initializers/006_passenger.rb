# See http://www.modrails.com/documentation/Users%20guide%20Apache.html#_smart_spawning_gotcha_1_unintential_file_descriptor_sharing

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      MEMCACHE.reset
    end
  end
end
