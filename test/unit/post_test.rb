require File.dirname(__FILE__) + '/../test_helper'

class PostTest < ActiveSupport::TestCase
  fixtures :users, :posts, :table_data
  
  def setup
    # TODO: revert these after testing in teardown
    CONFIG["enable_parents"] = true
    CONFIG["image_samples"] = true
    CONFIG["sample_width"] = 100
    CONFIG["sample_height"] = 100
    CONFIG["sample_ratio"] = 1.25
  end
  
  def create_post(params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :status => "active", :tags => "tag1 tag2", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg")}.merge(params))
  end
  
  def update_post(post, params = {})
    post.update_attributes({:updater_user_id => 1, :updater_ip_addr => '127.0.0.1'}.merge(params))
  end
  
  def create_comment(post, params = {})
    post.comments.create({:user_id => 1, :ip_addr => "127.0.0.1", :is_spam => false}.merge(params))
  end
  
  def test_api
    post = create_post
    assert_nothing_raised {post.to_json}
    assert_nothing_raised {post.to_xml}
  end
  
  if CONFIG["enable_caching"]
    def test_cache
      cache_version = Cache.get("$cache_version").to_i
      tag1_version = Cache.get("tag:tag1").to_i
      tag2_version = Cache.get("tag:tag2").to_i
      create_post
      assert_equal(cache_version + 1, Cache.get("$cache_version").to_i)
      assert_equal(tag1_version + 1, Cache.get("tag:tag1").to_i)
      assert_equal(tag2_version + 1, Cache.get("tag:tag2").to_i)
    end
  end
  
  def test_change_sequence
    post = create_post
    first_change_seq = post.change_seq
    update_post(post, :tags => "tag3 tag4")
    assert_equal(first_change_seq + 1, post.change_seq)
  end
  
  def test_comments
    post = create_post
    assert_equal(0, post.comments.size)
    assert_equal(0, post.recent_comments.size)
    
    comment1 = create_comment(post, :body => "comment 1")
    assert_equal(1, post.comments.size)
    assert_equal(1, post.recent_comments.size)
    
    comment2 = create_comment(post, :body => "comment 2")
    assert_equal(2, post.comments.size)
    assert_equal(2, post.recent_comments.size)
    assert_equal("comment 1", post.comments[0].body)
    assert_equal("comment 2", post.comments[1].body)
    
    comment3 = create_comment(post, :body => "comment 3")
    comment4 = create_comment(post, :body => "comment 4")
    comment5 = create_comment(post, :body => "comment 5")
    comment6 = create_comment(post, :body => "comment 6")
    comment7 = create_comment(post, :body => "comment 7")
    assert_equal(7, post.comments.size)
    assert_equal(6, post.recent_comments.size)
    assert_equal("comment 2", post.recent_comments[0].body)
  end
  
  def test_count
    # Includes posts from fixtures
    
    assert_equal(5, Post.fast_count)
    assert_equal(0, Post.fast_count("tag1"))
    assert_equal(0, Post.fast_count("tag2"))
    
    post1 = create_post(:tags => "tag1", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"))
    assert_equal(6, Post.fast_count)
    assert_equal(1, Post.fast_count("tag1"))
    assert_equal(0, Post.fast_count("tag2"))
    
    post2 = create_post(:tags => "tag2", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test2.jpg"))
    assert_equal(7, Post.fast_count)
    assert_equal(1, Post.fast_count("tag1"))
    assert_equal(1, Post.fast_count("tag2"))
    
    post3 = create_post(:tags => "tag2 tag3", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test3.jpg"))
    assert_equal(8, Post.fast_count)
    assert_equal(1, Post.fast_count("tag1"))
    assert_equal(2, Post.fast_count("tag2"))
    
    # These tests currently fail. This means that a deleted post won't decrement the tag's post count
    # until the post is deleted from the database (which then activates the database triggers which correct
    # the post counts).
    post3.destroy
    assert_equal(8, Post.count) # Post isn't actually deleted from database, just set status = deleted
    assert_equal(7, Post.fast_count)
    assert_equal(1, Post.fast_count("tag1"))
    assert_equal(1, Post.fast_count("tag2"))
    
    post2.destroy
    assert_equal(8, Post.count)
    assert_equal(6, Post.fast_count)
    assert_equal(1, Post.fast_count("tag1"))
    assert_equal(0, Post.fast_count("tag2"))
    
    post1.destroy
    assert_equal(8, Post.count)
    assert_equal(5, Post.fast_count)
    assert_equal(0, Post.fast_count("tag1"))
    assert_equal(0, Post.fast_count("tag2"))
  end
  
  def test_cgi_upload
    post = create_post(:tags => "tag1")
    assert(File.exists?(post.file_path), "File not found")
    assert(File.exists?(post.preview_path), "Preview not found")
    assert(File.exists?(post.sample_path), "Sample not found")
    assert_not_equal(0, File.size(post.file_path))
    assert_not_equal(0, File.size(post.preview_path))
    assert_not_equal(0, File.size(post.sample_path))
    assert_equal("fa033b0f3f0bb536770bbd5580575aac", post.md5)
  end
  
  def test_download_from_source
    post = create_post(:file => nil, :source => "http://www.google.com/intl/en_ALL/images/logo.gif")
    assert(File.exists?(post.file_path), "File not found")
    assert(File.exists?(post.preview_path), "Preview not found")
    assert_not_equal(0, File.size(post.file_path))
    assert_not_equal(0, File.size(post.preview_path))
    assert_equal("e80d1c59a673f560785784fb1ac10959", post.md5)
  end
  
  def test_uniqueness
    original_count = Post.count
    create_post(:tags => "tag1")
    assert_equal(original_count + 1, Post.count)
    post = create_post(:tags => "tag1")
    assert(post.errors.invalid?(:md5), "No error raised on duplicate MD5")
    assert_equal(original_count + 1, Post.count)
  end
  
  def test_non_image_upload
    post = create_post(:file => nil, :tags => "tag1", :source => "http://www.google.com/index.html")
    assert(post.errors.invalid?(:file), "Invalid content type was not rejected")
  end
  
  def test_parents
    # Test for nonexistent parent
    post = create_post(:parent_id => 1_000_000)
    assert(post.errors.invalid?(:parent_id), "Parent not validated")
    
    # Test to see if the has_children field is updated correctly
    p1 = create_post
    assert(!p1.has_children?, "Parent should not have any children")
    c1 = create_post(:file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test2.jpg"), :parent_id => p1.id)
    p1.reload
    assert(p1.has_children?, "Parent not updated after child was added")
    
    # Test to make sure favorites are assigned to a parent when a post is deleted
    c2 = create_post(:file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test3.jpg"), :parent_id => p1.id)
    Favorite.create(:post_id => c2.id, :user_id => 1)
    c2.destroy
    p1.reload
    assert_nil(Favorite.find(:first, :conditions => ["post_id = ? AND user_id = ?", c2.id, 1]))
    assert_not_nil(Favorite.find(:first, :conditions => ["post_id = ? AND user_id =?", p1.id, 1]))
    assert(p1.has_children?, "Parent should still have children")
    
    # Test to make sure has_children is updated when post is updated
    p2 = create_post(:file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test4.jpg"))
    update_post(c1, :parent_id => p2.id)
    p1.reload
    p2.reload
    assert(!p1.has_children?, "Parent should no longer have children")
    assert(p2.has_children?, "Parent should have children")
  end
end
