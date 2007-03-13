require 'yaml'

CONFIG = {}
LOCAL_CONFIG_FILE = "#{RAILS_ROOT}/config/local_config.yml"
DEFAULT_CONFIG = {
	"app_name"			=> "danbooru",
	"admin_contact"			=> "danbooru@moetry.org",
	"server_host"			=> "danbooru.donmai.us",
	"default_guest_name"		=> "EvilCanadian",
	"web_counter_directory"		=> "/images/webcounters/nekomimi100"
}

DEFAULT_CONFIG.each {|k,v| CONFIG[k] = v unless CONFIG.has_key?(k)}

def CONFIG.load!
	if File.exists?(LOCAL_CONFIG_FILE)
		File.open(LOCAL_CONFIG_FILE) do |cfp|
			YAML::load(cfp).each do |k, v|
				CONFIG[k] = v
			end
		end
	end
end

def CONFIG.save!
	File.open(LOCAL_CONFIG_FILE, 'w') do |f|
		f.write(self.to_yaml)
	end
end

CONFIG.load!
