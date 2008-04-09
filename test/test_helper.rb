ENV["RAILS_ENV"] = "test"
ENV["RAILS_TEST_DOWNLOAD"] ||= "true"

require File.dirname(__FILE__) + "/../config/environment"
require 'application'

require 'test/unit'
require 'active_record/fixtures'
require 'action_controller/test_process'
require 'action_web_service/test_invoke'
require 'breakpoint'

# Password for all users is password1

def create_fixtures(*table_names)
	Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
end

def create_cookie(key, value, domain = "")
	CGI::Cookie.new("name" => key, "value" => value, "expires" => 1.year.from_now, "path" => "/", "domain" => domain)
end

def upload_file(path, content_type, filename)
	t = Tempfile.new(filename)
	FileUtils.copy_file(path, t.path)
	(class << t; self; end).class_eval do
		alias local_path path
		define_method(:original_filename) {filename}
		define_method(:content_type) {content_type}
	end

	t
end

def upload_jpeg(path)
	upload_file(path, "image/jpeg", File.basename(path))
end

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
Test::Unit::TestCase.use_transactional_fixtures = true
Test::Unit::TestCase.use_instantiated_fixtures = false

class Test::Unit::TestCase
	# change this to a url to test auto-downloading
	DOWNLOAD_IMAGE = "http://www.google.com/intl/en_ALL/images/logo.gif"
	HTML_ATTACK = %{<img onclick="window.jref='http://goatse.cx'" /></html><a href="#">test</a><embed>bad</embed><script>bad</script>}
	SQL_ATTACK = %{'; DROP TABLE danbooru_dev;'}
end
