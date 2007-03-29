require 'yaml'

LOCAL_CONFIG_FILE = "#{RAILS_ROOT}/config/local_config.yml"

CONFIG = {
	"version" => "1.4.0"
}

File.open(LOCAL_CONFIG_FILE) do |cfp|
	YAML::load(cfp).each do |k, v|
		CONFIG[k] = v
	end
end
