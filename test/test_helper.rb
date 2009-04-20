ENV["RAILS_ENV"] = "test"

require File.dirname(__FILE__) + "/../config/environment"
require 'test_help'

CONFIG["enable_parent_posts"] = true
CONFIG["enable_account_email_activation"] = true

# Password for all users is password1

# def create_fixtures(*table_names)
#   Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
# end

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

def create_post(tags = "tag1", params = {})
  p = Post.new({:source => "", :rating => "s", :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{@test_number}.jpg")}.merge(params))
  p.user_id = params[:user_id] || 1
  p.score = params[:score] || 0
  p.width = params[:width] || 100
  p.height = params[:height] || 100
  p.ip_addr = params[:ip_addr] || "127.0.0.1"
  p.status = params[:status] || "active"
  p.save
  @test_number += 1
  p
end

def update_post(post, params = {})
  post.user_id = params[:user_id] if params[:user_id]
  post.score = params[:score] if params[:score]
  post.width = params[:width] if params[:width]
  post.height = params[:height] if params[:height]
  post.ip_addr = params[:ip_addr] if params[:ip_addr]
  post.status = params[:status] if params[:status]
  post.update_attributes({:updater_user_id => 1, :updater_ip_addr => '127.0.0.1'}.merge(params))
end

def create_note(params = {})
  Note.create({:post_id => 1, :user_id => 1, :x => 0, :y => 0, :width => 100, :height => 100, :is_active => true, :ip_addr => "127.0.0.1"}.merge(params))
end

def create_wiki(params = {})
  wp = WikiPage.new({:title => "hoge", :user_id => 1, :body => "hoge", :ip_addr => "127.0.0.1"}.merge(params))
  wp.is_locked = params[:is_locked] || false
  wp.save
  wp
end

def create_artist(params)
  Artist.create({:updater_id => 1, :updater_ip_addr => "127.0.0.1"}.merge(params))
end

def update_artist(artist, params)
  artist.update_attributes({:updater_id => 1, :updater_ip_addr => "127.0.0.1"}.merge(params))
end

def create_pool(params = {})
  pool = Pool.new({:name => "my pool", :post_count => 0, :is_public => false, :description => "pools", :updater_user_id => 1, :updater_ip_addr => "127.0.0.1"}.merge(params))
  pool.user_id = params[:user_id] || 1
  pool.save
  pool
end
  
def create_forum_post(msg, parent_id = nil, params = {})
  ForumPost.create({:creator_id => 1, :body => msg, :title => msg, :is_sticky => false, :is_locked => false, :parent_id => parent_id}.merge(params))
end

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures = false
end

class ActiveSupport::TestCase
  def assert_greater(expected, actual, message=nil)
    full_message = build_message(message, <<EOT, expected, actual)
<?> > <?> expected.
EOT
    assert_block(full_message) { expected > actual }
  end
end
